"""
Attachment helpers: which files we accept, pulling text out of documents,
and turning a message + its attachments into model input.
"""
import base64
import logging
import os

from .models import Attachment

logger = logging.getLogger(__name__)

MAX_FILES_PER_MESSAGE = 10
MAX_DOCUMENT_BYTES = 10 * 1024 * 1024  # 10 MB
MAX_IMAGE_BYTES = 4 * 1024 * 1024  # Groq's inline image limit
MAX_EXTRACTED_CHARS = 40_000  # per file, keeps prompts within context

IMAGE_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
}
TEXT_EXTENSIONS = {
    ".txt", ".md", ".markdown", ".csv", ".tsv", ".json", ".xml", ".yaml", ".yml",
    ".html", ".htm", ".css", ".js", ".jsx", ".ts", ".tsx", ".py", ".dart", ".java",
    ".kt", ".swift", ".c", ".h", ".cpp", ".hpp", ".cs", ".go", ".rs", ".rb", ".php",
    ".sql", ".sh", ".log", ".ini", ".toml", ".env.example",
}
PDF_EXTENSION = ".pdf"


class UnsupportedFile(ValueError):
    pass


def _extension(name):
    lower = name.lower()
    if lower.endswith(".env.example"):
        return ".env.example"
    return os.path.splitext(lower)[1]


def classify(name, size):
    """Return (kind, content_type) for an upload or raise UnsupportedFile."""
    ext = _extension(name)
    if ext in IMAGE_TYPES:
        if size > MAX_IMAGE_BYTES:
            raise UnsupportedFile("Images must be 4 MB or smaller.")
        return Attachment.KIND_IMAGE, IMAGE_TYPES[ext]
    if ext == PDF_EXTENSION or ext in TEXT_EXTENSIONS:
        if size > MAX_DOCUMENT_BYTES:
            raise UnsupportedFile("Files must be 10 MB or smaller.")
        content_type = "application/pdf" if ext == PDF_EXTENSION else "text/plain"
        return Attachment.KIND_DOCUMENT, content_type
    raise UnsupportedFile(
        "Unsupported file type. Attach images (PNG, JPG, WebP, GIF), PDFs, "
        "or text and code files."
    )


def extract_text(uploaded_file, name):
    """Best-effort text for a document; never raises."""
    try:
        uploaded_file.seek(0)
        if _extension(name) == PDF_EXTENSION:
            from pypdf import PdfReader

            reader = PdfReader(uploaded_file)
            text = "\n\n".join((page.extract_text() or "") for page in reader.pages)
            if not text.strip():
                return "(This PDF has no selectable text — it may be a scanned image.)"
        else:
            text = uploaded_file.read().decode("utf-8", errors="replace")
    except Exception:  # noqa: BLE001 - a broken file shouldn't break the upload
        logger.warning("Could not read text from %s", name, exc_info=True)
        return "(The contents of this file could not be read.)"
    finally:
        uploaded_file.seek(0)

    if len(text) > MAX_EXTRACTED_CHARS:
        text = text[:MAX_EXTRACTED_CHARS] + "\n\n[… file truncated …]"
    return text


def _image_data_url(attachment):
    with attachment.file.open("rb") as fh:
        encoded = base64.b64encode(fh.read()).decode("ascii")
    return f"data:{attachment.content_type};base64,{encoded}"


def model_content(message, include_images):
    """
    The model-facing content for one message.

    Documents are inlined as <file> blocks. Images are sent as image parts when
    `include_images` (the newest user turn on a vision model); otherwise they
    are mentioned by name so the conversation still makes sense.

    Returns (content, has_images) where content is a str or a list of parts.
    """
    attachments = list(message.attachments.all())
    text = message.content
    for a in attachments:
        if a.kind == Attachment.KIND_DOCUMENT:
            text += f'\n\n<file name="{a.name}">\n{a.extracted_text}\n</file>'
        elif not include_images:
            text += f"\n\n[Image attached earlier: {a.name}]"

    images = [a for a in attachments if a.kind == Attachment.KIND_IMAGE]
    if not include_images or not images:
        return text, False

    parts = [{"type": "text", "text": text.strip() or "Please look at the attached image."}]
    parts += [
        {"type": "image_url", "image_url": {"url": _image_data_url(a)}} for a in images
    ]
    return parts, True

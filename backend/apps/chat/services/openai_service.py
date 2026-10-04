"""
Thin async wrapper around an OpenAI-compatible Chat Completions streaming API
(Groq by default). Keeping this isolated makes it trivial to swap providers
later without touching the consumer.
"""
import logging
from typing import AsyncGenerator

from django.conf import settings
from openai import AsyncOpenAI

logger = logging.getLogger(__name__)

_client = AsyncOpenAI(
    api_key=settings.OPENAI_API_KEY,
    base_url=settings.OPENAI_BASE_URL,
    max_retries=0,
)


async def stream_chat_completion(
    messages: list[dict],
    model: str | None = None,
    reasoning_effort: str | None = None,
) -> AsyncGenerator[tuple[str, str], None]:
    """
    messages: list of {"role": "user"|"assistant"|"system", "content": str}
    Yields ("reasoning", text) chunks while a reasoning model (e.g. gpt-oss on
    Groq) is thinking, then ("content", text) chunks of the actual answer.
    `reasoning_effort` ("low" | "medium" | "high") asks a reasoning model to
    think less or more before answering.
    """
    try:
        stream = await _client.chat.completions.create(
            model=model or settings.OPENAI_MODEL,
            messages=messages,
            stream=True,
            temperature=0.7,
            extra_body={"reasoning_effort": reasoning_effort} if reasoning_effort else None,
        )

        async for chunk in stream:
            if not chunk.choices:
                continue
            delta = chunk.choices[0].delta
            if not delta:
                continue
            # Groq returns the model's thinking in a non-standard field.
            reasoning = (delta.model_extra or {}).get("reasoning")
            if reasoning:
                yield ("reasoning", reasoning)
            if delta.content:
                yield ("content", delta.content)
    except Exception:
        logger.exception("LLM API call failed")
        raise

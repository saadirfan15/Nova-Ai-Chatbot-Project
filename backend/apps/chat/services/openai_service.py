"""
Thin async wrapper around the OpenAI Chat Completions streaming API.
"""
import logging
from typing import AsyncGenerator

from django.conf import settings
from openai import AsyncOpenAI

logger = logging.getLogger(__name__)

_client = AsyncOpenAI(
    api_key=settings.OPENAI_API_KEY,
    base_url="https://api.groq.com/openai/v1",
    max_retries=0,
)


async def stream_chat_completion(
    messages: list[dict], model: str | None = None
) -> AsyncGenerator[str, None]:

    print("=" * 60)
    print("MESSAGES SENT TO MODEL:")
    print(messages)

    try:
        stream = await _client.chat.completions.create(
            model=model or settings.OPENAI_MODEL,
            messages=messages,
            stream=True,
            temperature=0.7,
        )

        print("STREAM STARTED")

        async for chunk in stream:
            print("CHUNK:", chunk)

            if not chunk.choices:
                continue

            delta = chunk.choices[0].delta

            if delta and delta.content:
                print("TOKEN:", repr(delta.content))
                yield delta.content

        print("STREAM FINISHED")

    except Exception as e:
        print("MODEL ERROR:", repr(e))
        logger.exception("Gemini/OpenAI API call failed")
        raise
"""
Thin async wrapper around the OpenAI Chat Completions streaming API.
Keeping this isolated makes it trivial to swap providers later
(Anthropic, local models, etc.) without touching the consumer.
"""
"""import logging
from typing import AsyncGenerator

from django.conf import settings
from openai import AsyncOpenAI

logger = logging.getLogger(__name__)

_client = AsyncOpenAI(
    api_key=settings.OPENAI_API_KEY,
    base_url="https://api.groq.com/openai/v1",
    max_retries=0,
)


async def stream_chat_completion(
    messages: list[dict], model: str | None = None
) -> AsyncGenerator[str, None]:
    """
"""messages: list of {"role": "user"|"assistant"|"system", "content": str}
    Yields text chunks as they arrive from OpenAI."""
"""
    try:
        stream = await _client.chat.completions.create(
            model=model or settings.OPENAI_MODEL,
            messages=messages,
            stream=True,
            temperature=0.7,
        )

        async for chunk in stream:
            delta = chunk.choices[0].delta
            if delta and delta.content:
                yield delta.content
    except Exception:
        logger.exception("Gemini/OpenAI API call failed")
        raise """
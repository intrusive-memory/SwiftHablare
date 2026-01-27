#!/usr/bin/env python3
"""
Extract speaker x-vector embeddings from reference audio clips for Qwen3-TTS voice cloning.

Pre-computes embeddings so the Swift app can condition the LM at runtime without
needing the speaker encoder model.

Usage:
    python extract_speaker_embeddings.py --clips-dir ./reference_clips [--output-dir PATH]

Expected clips directory structure:
    reference_clips/
    ├── voice_male_01.wav
    ├── voice_male_01.txt   # transcript of the wav
    ├── voice_female_01.wav
    ├── voice_female_01.txt
    └── ...
"""

import argparse
import json
import logging
from pathlib import Path

import numpy as np
import soundfile as sf

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)


def load_model():
    """Load the full Qwen3TTS model for speaker encoding."""
    log.info("Loading Qwen3TTSModel (this downloads several GB on first run)...")
    from qwen_tts import Qwen3TTSModel

    model = Qwen3TTSModel.from_pretrained(
        "Qwen/Qwen3-TTS-12Hz-1.7B-Base", device="cpu"
    )
    model.eval()
    log.info("Model loaded.")
    return model


def extract_embedding(model, audio_path: Path, transcript: str) -> np.ndarray:
    """Extract x-vector speaker embedding from a reference audio clip."""
    audio, sr = sf.read(str(audio_path))
    log.info("  Audio: %.1f sec, %d Hz", len(audio) / sr, sr)

    # Use the model's voice clone prompt creation to get the x-vector
    import torch

    with torch.no_grad():
        embedding = model.create_voice_clone_prompt(
            ref_audio=audio,
            ref_audio_sr=sr,
            ref_text=transcript,
        )

    if isinstance(embedding, torch.Tensor):
        embedding = embedding.cpu().numpy()

    return embedding


def main():
    parser = argparse.ArgumentParser(
        description="Extract speaker embeddings from reference audio clips"
    )
    parser.add_argument(
        "--clips-dir",
        type=Path,
        required=True,
        help="Directory containing .wav + .txt pairs",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Output directory (default: Resources/Models/QwenTTS/voices/)",
    )
    args = parser.parse_args()

    clips_dir: Path = args.clips_dir
    if not clips_dir.is_dir():
        log.error("Clips directory not found: %s", clips_dir)
        raise SystemExit(1)

    output_dir: Path = args.output_dir or (
        Path(__file__).resolve().parent.parent / "Resources" / "Models" / "QwenTTS" / "voices"
    )
    output_dir.mkdir(parents=True, exist_ok=True)

    # Find all wav files with matching transcripts
    wav_files = sorted(clips_dir.glob("*.wav"))
    if not wav_files:
        log.error("No .wav files found in %s", clips_dir)
        raise SystemExit(1)

    model = load_model()

    voices = []
    for wav_path in wav_files:
        name = wav_path.stem
        txt_path = wav_path.with_suffix(".txt")

        if not txt_path.exists():
            log.warning("Skipping %s — no matching .txt transcript found.", wav_path.name)
            continue

        transcript = txt_path.read_text().strip()
        if not transcript:
            log.warning("Skipping %s — transcript is empty.", wav_path.name)
            continue

        log.info("Processing: %s", name)
        embedding = extract_embedding(model, wav_path, transcript)

        # Save embedding
        npy_path = output_dir / f"{name}.npy"
        np.save(str(npy_path), embedding)
        log.info("  Saved embedding: %s (shape=%s, dtype=%s)", npy_path, embedding.shape, embedding.dtype)

        # Copy wav for reference / documentation
        import shutil

        wav_dest = output_dir / wav_path.name
        if wav_dest != wav_path:
            shutil.copy2(wav_path, wav_dest)

        voices.append({
            "name": name,
            "embedding_file": f"{name}.npy",
            "reference_audio": wav_path.name,
            "transcript": transcript,
            "embedding_shape": list(embedding.shape),
            "embedding_dtype": str(embedding.dtype),
        })

    # Write voice catalog
    catalog_path = output_dir / "voices.json"
    catalog_path.write_text(json.dumps(voices, indent=2))
    log.info("Voice catalog written: %s (%d voices)", catalog_path, len(voices))

    if not voices:
        log.warning("No voices were processed. Check that .wav/.txt pairs exist in %s", clips_dir)
        raise SystemExit(1)

    log.info("Done. %d voice embeddings extracted.", len(voices))


if __name__ == "__main__":
    main()

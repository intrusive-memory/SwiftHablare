#!/usr/bin/env python3
"""
Convert Qwen3-TTS codec decoder (Qwen3TTSTokenizerV2Decoder) to CoreML .mlpackage format.

Only the codec decoder is converted — the autoregressive LM stays as safetensors
for mlx-swift-lm. The codec decoder is feed-forward (codes → waveform), ideal for
CoreML / Apple Neural Engine.

Usage:
    python convert_qwen_tts_coreml.py [--output-dir PATH] [--buckets 3,10,30,45]
"""

import argparse
import json
import logging
import sys
from pathlib import Path

import coremltools as ct
import numpy as np
import torch
import torch.nn as nn

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

# 12 Hz frame rate, 1920 samples per frame at 24 kHz
FRAME_RATE_HZ = 12
SAMPLES_PER_FRAME = 1920
SAMPLE_RATE = 24000
NUM_CODEBOOKS = 16

BUCKETS = {
    3: 38,    # ~3 sec
    10: 125,  # ~10 sec
    30: 375,  # ~30 sec
    45: 563,  # ~45 sec
}


class CodecDecoderWrapper(nn.Module):
    """Wraps Qwen3TTSTokenizerV2Decoder for tracing.

    - Replaces Dropout with Identity (inference mode)
    - Casts int32 input to int64 for PyTorch Embedding compatibility
      (CoreML integer inputs are int32)
    """

    def __init__(self, decoder: nn.Module):
        super().__init__()
        self.decoder = decoder
        self._replace_dropout(self.decoder)
        self.decoder.eval()

    @staticmethod
    def _replace_dropout(module: nn.Module):
        for name, child in module.named_children():
            if isinstance(child, nn.Dropout):
                setattr(module, name, nn.Identity())
            else:
                CodecDecoderWrapper._replace_dropout(child)

    def forward(self, codes: torch.Tensor) -> torch.Tensor:
        """
        Args:
            codes: int32 tensor of shape (1, 16, T) — audio codes from the LM.
        Returns:
            waveform: float32 tensor of shape (1, 1, T*1920) — PCM samples.
        """
        codes = codes.to(torch.int64)
        return self.decoder(codes)


def load_decoder():
    """Load the codec decoder from qwen-tts tokenizer."""
    log.info("Loading Qwen3TTSTokenizer (this downloads ~200MB on first run)...")
    from qwen_tts import Qwen3TTSTokenizer

    tokenizer = Qwen3TTSTokenizer.from_pretrained(
        "Qwen/Qwen3-TTS-Tokenizer-12Hz", device="cpu"
    )
    decoder = tokenizer.model.decoder
    log.info("Decoder loaded: %s", type(decoder).__name__)
    return decoder


def trace_decoder(wrapper: CodecDecoderWrapper, T: int):
    """Trace the decoder with dummy codes of shape (1, 16, T)."""
    dummy = torch.randint(0, 1024, (1, NUM_CODEBOOKS, T), dtype=torch.int32)
    log.info("Tracing with input shape %s ...", tuple(dummy.shape))

    try:
        traced = torch.jit.trace(wrapper, dummy)
        return traced
    except Exception as e:
        log.warning("Strict trace failed: %s. Trying strict=False...", e)

    try:
        traced = torch.jit.trace(wrapper, dummy, strict=False)
        log.info("Traced with strict=False.")
        return traced
    except Exception as e:
        log.error("Trace failed even with strict=False: %s", e)
        log.error(
            "Fallback: consider splitting decoder into sub-models or using ONNX intermediate."
        )
        raise


def convert_to_coreml(traced_model, T: int):
    """Convert a traced PyTorch model to CoreML .mlpackage."""
    input_shape = ct.Shape(shape=(1, NUM_CODEBOOKS, T))
    expected_output_samples = T * SAMPLES_PER_FRAME

    log.info("Converting to CoreML (T=%d, output_samples=%d)...", T, expected_output_samples)

    mlmodel = ct.convert(
        traced_model,
        inputs=[ct.TensorType(name="codes", shape=input_shape, dtype=np.int32)],
        outputs=[ct.TensorType(name="waveform")],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS18,
        convert_to="mlprogram",
    )
    return mlmodel


def validate(
    wrapper: CodecDecoderWrapper,
    mlmodel,
    T: int,
    tolerance: float = 0.01,
):
    """Validate CoreML output against PyTorch output."""
    log.info("Validating (T=%d)...", T)
    dummy = torch.randint(0, 1024, (1, NUM_CODEBOOKS, T), dtype=torch.int32)

    # PyTorch reference
    with torch.no_grad():
        pt_out = wrapper(dummy).numpy()

    # CoreML prediction
    prediction = mlmodel.predict({"codes": dummy.numpy()})
    cm_out = prediction["waveform"]

    # Shape check
    expected_samples = T * SAMPLES_PER_FRAME
    assert pt_out.shape[-1] == expected_samples, (
        f"PyTorch output shape mismatch: {pt_out.shape}, expected last dim {expected_samples}"
    )
    assert cm_out.shape[-1] == expected_samples, (
        f"CoreML output shape mismatch: {cm_out.shape}, expected last dim {expected_samples}"
    )

    # Numeric parity
    max_diff = np.max(np.abs(pt_out.astype(np.float32) - cm_out.astype(np.float32)))
    log.info("Max absolute diff: %.6f (tolerance: %.4f)", max_diff, tolerance)
    if max_diff > tolerance:
        log.warning(
            "Numeric parity FAILED: max_diff=%.6f exceeds tolerance=%.4f",
            max_diff,
            tolerance,
        )
        return False

    # Non-silence check
    rms = np.sqrt(np.mean(cm_out.astype(np.float32) ** 2))
    if rms < 1e-6:
        log.warning("Output appears silent (RMS=%.8f).", rms)
        return False

    log.info("Validation passed (max_diff=%.6f, rms=%.6f).", max_diff, rms)
    return True


def main():
    parser = argparse.ArgumentParser(description="Convert Qwen3-TTS codec decoder to CoreML")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "Resources" / "Models" / "QwenTTS",
    )
    parser.add_argument(
        "--buckets",
        type=str,
        default="3,10,30,45",
        help="Comma-separated bucket durations in seconds",
    )
    parser.add_argument(
        "--skip-validation",
        action="store_true",
        help="Skip numeric validation (faster)",
    )
    args = parser.parse_args()

    bucket_durations = [int(b) for b in args.buckets.split(",")]
    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load and wrap
    decoder = load_decoder()
    wrapper = CodecDecoderWrapper(decoder)

    metadata = {
        "model": "Qwen3-TTS-12Hz-1.7B-Base",
        "component": "codec_decoder",
        "sample_rate": SAMPLE_RATE,
        "frame_rate_hz": FRAME_RATE_HZ,
        "samples_per_frame": SAMPLES_PER_FRAME,
        "num_codebooks": NUM_CODEBOOKS,
        "buckets": {},
    }

    all_passed = True

    for dur in bucket_durations:
        T = BUCKETS.get(dur)
        if T is None:
            T = dur * FRAME_RATE_HZ
            log.info("Custom bucket %ds → T=%d frames", dur, T)

        name = f"qwen_tts_codec_decoder_{dur}s"
        out_path = output_dir / f"{name}.mlpackage"

        log.info("=== Bucket %ds (T=%d) ===", dur, T)

        traced = trace_decoder(wrapper, T)
        mlmodel = convert_to_coreml(traced, T)

        if not args.skip_validation:
            passed = validate(wrapper, mlmodel, T)
            if not passed:
                all_passed = False

        mlmodel.save(str(out_path))
        log.info("Saved: %s", out_path)

        metadata["buckets"][f"{dur}s"] = {
            "frames": T,
            "output_samples": T * SAMPLES_PER_FRAME,
            "duration_sec": T / FRAME_RATE_HZ,
            "file": f"{name}.mlpackage",
        }

    # Write metadata
    meta_path = output_dir / "metadata.json"
    meta_path.write_text(json.dumps(metadata, indent=2))
    log.info("Metadata written: %s", meta_path)

    if not all_passed:
        log.warning("Some validations failed — check output above.")
        sys.exit(1)

    log.info("Done. All buckets converted successfully.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Convert Qwen3-TTS codec decoder (Qwen3TTSTokenizerV2Decoder) weights to MLX format.

Only the codec decoder is converted — the autoregressive LM stays as safetensors
for mlx-swift-lm. Both components run on Apple Silicon via MLX at runtime.

The script exports:
  - Decoder weights as safetensors (float16)
  - Model config JSON for the MLX-Swift decoder implementation
  - Metadata JSON with model info

Usage:
    python convert_qwen_tts_coreml.py [--output-dir PATH]
"""

import argparse
import json
import logging
import sys
from pathlib import Path

import numpy as np
import torch

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger(__name__)

SAMPLE_RATE = 24000
FRAME_RATE_HZ = 12
NUM_CODEBOOKS = 16


def load_decoder():
    """Load the codec decoder from qwen-tts tokenizer."""
    log.info("Loading Qwen3TTSTokenizer...")
    from qwen_tts import Qwen3TTSTokenizer

    tokenizer = Qwen3TTSTokenizer.from_pretrained("Qwen/Qwen3-TTS-Tokenizer-12Hz")
    decoder = tokenizer.model.decoder
    config = tokenizer.model.config
    log.info("Decoder loaded: %s", type(decoder).__name__)
    return decoder, config


def extract_config(decoder, config) -> dict:
    """Extract decoder architecture config for MLX reimplementation."""
    # Count parameters
    total_params = sum(p.numel() for p in decoder.parameters())

    # Inspect structure to extract hyperparameters
    mlx_config = {
        "model_type": "qwen3_tts_codec_decoder",
        "sample_rate": SAMPLE_RATE,
        "frame_rate_hz": FRAME_RATE_HZ,
        "num_codebooks": NUM_CODEBOOKS,
        "total_params": total_params,
    }

    # Extract from HF config if available
    for attr in [
        "hidden_size", "num_attention_heads", "num_hidden_layers",
        "intermediate_size", "num_quantizers", "codebook_size",
        "n_q_semantic", "n_q_acoustic",
        "upsample_ratios", "decoder_channels", "decoder_kernel_sizes",
    ]:
        val = getattr(config, attr, None)
        if val is None:
            # Try decoder_config sub-object
            dc = getattr(config, "decoder_config", None)
            if dc:
                val = getattr(dc, attr, None)
        if val is not None:
            # Convert lists/tuples for JSON
            if isinstance(val, (list, tuple)):
                val = list(val)
            mlx_config[attr] = val

    # Infer from weights if config is sparse
    if "hidden_size" not in mlx_config:
        # pre_transformer.input_proj.weight is (hidden, input_dim)
        try:
            w = dict(decoder.named_parameters())["pre_transformer.input_proj.weight"]
            mlx_config["transformer_hidden_size"] = w.shape[0]
            mlx_config["transformer_input_dim"] = w.shape[1]
        except KeyError:
            pass

    return mlx_config


def convert_weights_to_safetensors(decoder, output_path: Path):
    """Export decoder weights as safetensors in float16."""
    from safetensors.torch import save_file

    state_dict = {}
    for name, param in decoder.named_parameters():
        state_dict[name] = param.detach().half().contiguous()

    save_file(state_dict, str(output_path))
    size_mb = output_path.stat().st_size / (1024 * 1024)
    log.info("Saved weights: %s (%.1f MB)", output_path, size_mb)
    return len(state_dict)


def validate_weights(decoder, output_path: Path, tolerance: float = 1e-3):
    """Validate saved weights can be loaded and match originals."""
    from safetensors.torch import load_file

    log.info("Validating saved weights...")
    loaded = load_file(str(output_path))

    mismatches = 0
    for name, param in decoder.named_parameters():
        if name not in loaded:
            log.warning("Missing key: %s", name)
            mismatches += 1
            continue
        original = param.detach().half()
        diff = (original - loaded[name]).abs().max().item()
        if diff > tolerance:
            log.warning("Mismatch for %s: max_diff=%.6f", name, diff)
            mismatches += 1

    if mismatches == 0:
        log.info("All %d weight tensors validated OK.", len(loaded))
    else:
        log.warning("%d mismatches found.", mismatches)
    return mismatches == 0


def validate_forward_pass(decoder):
    """Run a forward pass to verify the decoder works and capture output stats."""
    log.info("Running validation forward pass...")
    decoder.eval()
    dummy = torch.randint(0, 1024, (1, NUM_CODEBOOKS, 38), dtype=torch.int64)
    with torch.no_grad():
        out = decoder(dummy)
    log.info(
        "Forward pass OK: shape=%s, range=[%.4f, %.4f], rms=%.6f",
        tuple(out.shape),
        out.min().item(),
        out.max().item(),
        out.float().pow(2).mean().sqrt().item(),
    )
    return {
        "output_shape": list(out.shape),
        "output_min": float(out.min()),
        "output_max": float(out.max()),
        "output_rms": float(out.float().pow(2).mean().sqrt()),
        "test_input_frames": 38,
    }


def main():
    parser = argparse.ArgumentParser(
        description="Convert Qwen3-TTS codec decoder to MLX safetensors"
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "Resources" / "Models" / "QwenTTS",
    )
    parser.add_argument(
        "--skip-validation",
        action="store_true",
        help="Skip weight and forward-pass validation",
    )
    args = parser.parse_args()

    output_dir: Path = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    # Load
    decoder, config = load_decoder()

    # Forward pass validation (before conversion, to ensure model works)
    forward_stats = {}
    if not args.skip_validation:
        forward_stats = validate_forward_pass(decoder)

    # Extract config
    mlx_config = extract_config(decoder, config)
    config_path = output_dir / "config.json"
    config_path.write_text(json.dumps(mlx_config, indent=2))
    log.info("Config written: %s", config_path)

    # Convert weights
    weights_path = output_dir / "codec_decoder.safetensors"
    num_tensors = convert_weights_to_safetensors(decoder, weights_path)

    # Validate weights roundtrip
    if not args.skip_validation:
        if not validate_weights(decoder, weights_path):
            log.error("Weight validation failed!")
            sys.exit(1)

    # Write metadata
    metadata = {
        "model": "Qwen3-TTS-12Hz-1.7B-Base",
        "component": "codec_decoder",
        "format": "safetensors",
        "dtype": "float16",
        "sample_rate": SAMPLE_RATE,
        "frame_rate_hz": FRAME_RATE_HZ,
        "num_codebooks": NUM_CODEBOOKS,
        "num_tensors": num_tensors,
        "total_params": mlx_config.get("total_params"),
        "files": {
            "weights": "codec_decoder.safetensors",
            "config": "config.json",
        },
        "validation": forward_stats,
    }
    meta_path = output_dir / "metadata.json"
    meta_path.write_text(json.dumps(metadata, indent=2))
    log.info("Metadata written: %s", meta_path)

    log.info("Done. MLX-compatible weights exported to %s", output_dir)


if __name__ == "__main__":
    main()

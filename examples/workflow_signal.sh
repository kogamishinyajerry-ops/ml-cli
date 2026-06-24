#!/bin/bash
# =============================================================================
# CLI 工作流演示 1: 信号分析流水线
# =============================================================================
# 从音频文件到频谱分析报告的完整 CLI 管道
# 体现 CLI anything:每一步都是独立工具,用管道组合

set -euo pipefail
export PATH="$HOME/ml-cli/bin:$PATH"

AUDIO_FILE="$1"

echo "=== Signal Analysis Pipeline ==="
echo "File: ${AUDIO_FILE}"

# Step 1: Get basic info
echo ""
echo "--- 1. File Info ---"
ml signal "$AUDIO_FILE" --fft --json | jq '{fs: .sample_rate, dur: .duration, peak_hz: .peak_freq}'

# Step 2: Check peak frequency
echo ""
echo "--- 2. Peak Frequency Analysis ---"
PEAK_HZ=$(ml signal "$AUDIO_FILE" --fft --json | jq -r '.peak_freq')
echo "Peak frequency: ${PEAK_HZ} Hz"

# Step 3: Determine if it's a tone or noise based on bandwidth
echo ""
echo "--- 3. Signal Type Classification ---"
BW_CHECK=$(ml eval "f=ml.read_json('/dev/stdin'); threshold=50; is_tone=abs(f.peak_freq-f.frequency(f.magnitude>0.5*max(f.magnitude)))|<$threshold; disp(is_tone)" <<< "$(ml signal "$AUDIO_FILE" --fft --json)")

# Step 4: Generate plot
echo ""
echo "--- 4. Generate Spectrum Plot ---"
ml plot "x=$(ml signal "$AUDIO_FILE" --fft --json | jq '.frequency');y=$(ml signal "$AUDIO_FILE" --fft --json | jq '.magnitude');plot(x,y);title('FFT Spectrum');xlabel('Freq (Hz)');ylabel('Magnitude')" --save /tmp/signal_spectrum.png

echo ""
echo "Output: /tmp/signal_spectrum.png"
echo "=== Pipeline Complete ==="

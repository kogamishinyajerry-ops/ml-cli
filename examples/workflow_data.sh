#!/bin/bash
# =============================================================================
# CLI 工作流演示 2: 数据分析 + 可视化
# =============================================================================
# 从 CSV 到统计分析到可视化的完整 CLI 管道

set -euo pipefail
export PATH="$HOME/ml-cli/bin:$PATH"

echo "=== Data Analysis Pipeline ==="

# Create sample data
echo "Creating sample data..."
cat > /tmp/ml_demo_data.csv <<EOF
temp,pressure,humidity,wind_speed
22.5,1013.2,45.0,5.2
23.1,1012.8,47.3,6.1
21.8,1014.1,42.1,3.8
24.0,1011.5,50.2,7.5
25.3,1010.2,55.0,8.9
22.0,1013.5,44.2,4.5
26.1,1009.8,58.1,10.2
23.5,1012.0,46.5,6.7
20.5,1015.0,40.3,3.1
24.8,1011.0,52.4,8.0
EOF

# Step 1: Basic statistics using m (matlab-skills CLI)
echo ""
echo "--- 1. Basic Statistics ---"
export PATH="$HOME/matlab-skills/cli:$PATH"
m data /tmp/ml_demo_data.csv --stats --json | jq '.'

# Step 2: Correlation analysis using ml
echo ""
echo "--- 2. Correlation Analysis ---"
export PATH="$HOME/ml-cli/bin:$PATH"
ml eval "
D=readmatrix('/tmp/ml_demo_data.csv','NumHeaderLines',1);
R=corrcoef(D);
fprintf('Temperature-Pressure corr: %.3f\n', R(1,2));
fprintf('Temperature-Humidity corr: %.3f\n', R(1,3));
fprintf('Temperature-Wind corr: %.3f\n', R(1,4));
fprintf('Pressure-Humidity corr: %.3f\n', R(2,3));
" 2>&1 | grep -v "Trial License"

# Step 3: Predictive model (linear regression)
echo ""
echo "--- 3. Linear Model: Wind ~ Temperature ---"
ml eval --json "
D=readmatrix('/tmp/ml_demo_data.csv','NumHeaderLines',1);
T=D(:,1); W=D(:,4);
X=[ones(size(T)) T];
b=X\\W;
struct('intercept',b(1),'slope',b(2),'r_squared',corr(T,W)^2)
" 2>&1 | grep -v "Trial License" | jq '.'

# Step 4: Generate report plots
echo ""
echo "--- 4. Generating Plots ---"
ml plot "
D=readmatrix('/tmp/ml_demo_data.csv','NumHeaderLines',1);
subplot(2,2,1); plot(D(:,1),D(:,3),'ro'); title('Temp vs Humidity'); xlabel('Temp'); ylabel('Humidity');
subplot(2,2,2); plot(D(:,1),D(:,4),'bo'); title('Temp vs Wind'); xlabel('Temp'); ylabel('Wind');
subplot(2,2,3); histogram(D(:,1)); title('Temperature Dist');
subplot(2,2,4); histogram(D(:,2)); title('Pressure Dist');
" --save /tmp/ml_data_report.png

echo "Report saved: /tmp/ml_data_report.png"
echo "=== Pipeline Complete ==="

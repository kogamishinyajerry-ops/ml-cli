#!/bin/bash
# =============================================================================
# CLI 工作流演示 3: 航空工程计算
# =============================================================================
# 从大气参数到升阻比到性能估算的完整 CLI 管道

set -euo pipefail
export PATH="$HOME/ml-cli/bin:$PATH"

echo "=== Aerospace Engineering Pipeline ==="
echo ""

# Step 1: Calculate ISA conditions at multiple altitudes
echo "--- 1. Standard Atmosphere at Multiple Altitudes ---"
for alt in 0 2000 5000 10000; do
    ISA=$(ml eval "[T,a,P,rho]=atmoscoesa($alt); fprintf('alt=%5dm  T=%.1fK  P=%.0fPa  rho=%.4f  a=%.0fm/s\n',$alt,T,P,rho,a)" 2>&1 | grep -v "Trial")
    echo "  $ISA"
done

# Step 2: Calculate dynamic pressure at cruise
echo ""
echo "--- 2. Dynamic Pressure @ Cruise (250 m/s, 10km) ---"
ml eval "[~,~,~,rho]=atmoscoesa(10000); V=250; Q=0.5*rho*V^2; fprintf('Q = %.0f Pa\n',Q)" 2>&1 | grep -v "Trial"

# Step 3: Calculate lift coefficient needed for level flight
echo ""
echo "--- 3. Lift Coefficient for Level Flight ---"
ml eval "
[~,~,~,rho]=atmoscoesa(10000);
V=250; m=50000; S=100;
W=m*9.81; Q=0.5*rho*V^2;
CL=W/(Q*S);
fprintf('CL required = %.3f\n',CL);
AR=8; e=0.8;
k=1/(pi*AR*e);
CD0=0.02;
CD=CD0+k*CL^2;
fprintf('CD = %.4f, L/D = %.1f\n',CD,CL/CD);
" 2>&1 | grep -v "Trial"

# Step 4: Breguet range estimation
echo ""
echo "--- 4. Breguet Range Estimation ---"
ml eval "
[~,~,~,rho]=atmoscoesa(10000);
V=250; m0=50000; mf=10000; S=100;
W0=m0*9.81; W1=(m0-mf)*9.81;
CL=W0/(0.5*rho*V^2*S);
CD=0.02+1/(pi*8*0.8)*CL^2;
LD=CL/CD;
c_t=0.6/3600;
R=(V/c_t)*LD*log(W0/W1);
fprintf('Estimated range: %.0f km (%.0f nm)\n',R/1000,R/1852);
fprintf('Endurance: %.1f hours\n',(1/c_t)*LD*log(W0/W1)/3600);
" 2>&1 | grep -v "Trial"

# Step 5: Mach number analysis
echo ""
echo "--- 5. Mach Number vs Altitude ---"
for alt in 0 5000 10000; do
    M=$(ml aero --alt "$alt" --mach 0.78 2>&1 | grep -v "Trial" | grep -oP 'V=[0-9.]+')
    echo "  At ${alt}m, M=0.78: ${M}"
done

echo ""
echo "=== Pipeline Complete ==="

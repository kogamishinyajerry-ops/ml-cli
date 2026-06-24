%% {{NAME}} — Financial Analysis Template
% 自动生成 by ml template decision
% 日期: {{DATE}}
% 用途: 投资回报分析 / NPV / IRR / 蒙特卡洛模拟

clear; clc; close all;

%% 1. Define investment parameters
initial_investment = 1000000;             % Initial cost [$]
annual_revenue     = [200000 350000 500000 600000 700000];  % 5-year projections
annual_cost        = [80000  120000 150000 180000 200000];
discount_rate      = 0.08;                % 8% WACC
tax_rate           = 0.25;                % 25% corporate tax
salvage_value      = 200000;              % Year 5 salvage

%% 2. Cash flow calculation
years = 1:length(annual_revenue);
cash_flow = zeros(1, length(years));

for k = 1:length(years)
    ebit = annual_revenue(k) - annual_cost(k);
    tax = ebit * tax_rate;
    cash_flow(k) = ebit - tax;
    fprintf('Year %d: Revenue=$%.0fK Cost=$%.0fK CF=$%.0fK\n', ...
        k, annual_revenue(k)/1000, annual_cost(k)/1000, cash_flow(k)/1000);
end

% Add salvage value in last year
cash_flow(end) = cash_flow(end) + salvage_value;

%% 3. Financial metrics
% Net Present Value
npv = -initial_investment;
for k = 1:length(cash_flow)
    npv = npv + cash_flow(k) / (1 + discount_rate)^k;
end

% Internal Rate of Return
cf_all = [-initial_investment, cash_flow];
try
    irr_val = irr(cf_all);
catch
    irr_val = fzero(@(r) npv_func(r, cf_all), 0.1);
end

% Payback period
cumulative = -initial_investment;
payback = NaN;
for k = 1:length(cash_flow)
    cumulative = cumulative + cash_flow(k);
    if cumulative >= 0 && isnan(payback)
        payback = k - 1 + (cumulative - cash_flow(k)) / cash_flow(k);
    end
end

% ROI
total_return = sum(cash_flow) - initial_investment;
roi = total_return / initial_investment * 100;

fprintf('\n=== Financial Analysis ===\n');
fprintf('NPV:           $%.0f\n', npv);
fprintf('IRR:           %.1f%%\n', irr_val*100);
fprintf('Payback:       %.1f years\n', payback);
fprintf('ROI:           %.1f%%\n', roi);
fprintf('Decision:      %s\n', ternary(npv > 0, 'ACCEPT ✓', 'REJECT ✗'));

%% 4. Sensitivity analysis
figure('Name', 'Sensitivity Analysis', 'Position', [100 100 800 500]);

% Vary discount rate ±5%
rates = linspace(discount_rate-0.05, discount_rate+0.05, 20);
npv_sens = zeros(size(rates));
for i = 1:length(rates)
    npv_sens(i) = -initial_investment;
    for k = 1:length(cash_flow)
        npv_sens(i) = npv_sens(i) + cash_flow(k)/(1+rates(i))^k;
    end
end

plot(rates*100, npv_sens/1000, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 4);
hold on;
yline(0, 'r--', 'NPV=0', 'LineWidth', 1);
xline(discount_rate*100, 'k--', sprintf('Base=%.0f%%', discount_rate*100), 'LineWidth', 1);
xlabel('Discount Rate [%]'); ylabel('NPV [$K]');
title('NPV Sensitivity to Discount Rate'); grid on;

saveas(gcf, 'financial_analysis.png'); close(gcf);

%% 5. Monte Carlo simulation
n_sims = 1000;
npv_mc = zeros(n_sims, 1);

for i = 1:n_sims
    % Randomize revenue (±20%)
    rev_rand = annual_revenue .* (1 + 0.2*randn(1, length(years)));
    rev_rand = max(rev_rand, 0);
    cost_rand = annual_cost .* (1 + 0.1*randn(1, length(years)));

    cf_rand = zeros(1, length(years));
    for k = 1:length(years)
        ebit_rand = rev_rand(k) - cost_rand(k);
        tax_rand = ebit_rand * tax_rate;
        cf_rand(k) = ebit_rand - tax_rand;
    end
    cf_rand(end) = cf_rand(end) + salvage_value;

    npv_mc(i) = -initial_investment;
    for k = 1:length(cf_rand)
        npv_mc(i) = npv_mc(i) + cf_rand(k)/(1+discount_rate)^k;
    end
end

prob_positive = sum(npv_mc > 0) / n_sims * 100;
fprintf('\nMonte Carlo (%d simulations):\n', n_sims);
fprintf('  Mean NPV:    $%.0f\n', mean(npv_mc));
fprintf('  Std NPV:     $%.0f\n', std(npv_mc));
fprintf('  P(NPV > 0):  %.1f%%\n', prob_positive);
fprintf('  VaR 95%%:     $%.0f\n', prctile(npv_mc, 5));

fprintf('\nFinancial analysis complete.\n');

function result = tern(cond, a, b)
    if cond, result = a; else, result = b; end
end

function f = npv_func(r, cf)
    f = 0;
    for k = 1:length(cf)
        f = f + cf(k)/(1+r)^(k-1);
    end
end

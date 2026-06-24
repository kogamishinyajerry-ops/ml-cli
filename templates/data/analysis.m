%% {{NAME}} — Data Analysis Template
% 自动生成 by ml template data
% 日期: {{DATE}}

clear; clc; close all;

%% 1. Load data
% data = readmatrix('data.csv');
% data = readtable('data.csv');
% Replace with your data loading code
data = randn(100, 4);  % example: 100 samples, 4 variables

%% 2. Explore data
[n, p] = size(data);
fprintf('Dataset: %d samples, %d variables\n', n, p);

% Basic statistics
stats = struct();
for j = 1:p
    col = data(:, j);
    fprintf('--- Variable %d ---\n', j);
    fprintf('  Mean:     %.4f\n', mean(col));
    fprintf('  Median:   %.4f\n', median(col));
    fprintf('  Std Dev:  %.4f\n', std(col));
    fprintf('  Min/Max:  %.4f / %.4f\n', min(col), max(col));
    fprintf('  Skewness: %.4f\n', skewness(col));
end

%% 3. Visualize
figure('Name', 'Data Overview', 'Position', [100 100 1000 600]);

subplot(2, 2, 1);
boxplot(data);
title('Box Plots'); xlabel('Variable'); ylabel('Value');

subplot(2, 2, 2);
histogram(data(:, 1), 20);
title('Histogram: Variable 1');

subplot(2, 2, 3);
plot(data(:, 1), data(:, 2), 'o');
title('Var1 vs Var2'); xlabel('Var1'); ylabel('Var2');

subplot(2, 2, 4);
R = corrcoef(data);
imagesc(R); colorbar; caxis([-1 1]); colormap(jet);
title('Correlation Matrix');

saveas(gcf, 'data_overview.png');
close(gcf);

%% 4. Export results
fprintf('\nAnalysis complete. Check data_overview.png\n');

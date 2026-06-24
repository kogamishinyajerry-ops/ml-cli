%% {{NAME}} — Machine Learning Template
% 自动生成 by ml template ml
% 日期: {{DATE}}

clear; clc; close all;

%% 1. Generate/load data
% Classification example with 3 classes
rng(42);
n_per_class = 100;

% Class 1: centered at (0, 0)
X1 = randn(n_per_class, 2) * 0.5;
% Class 2: centered at (3, 3)
X2 = randn(n_per_class, 2) * 0.5 + 3;
% Class 3: centered at (-2, 3)
X3 = randn(n_per_class, 2) * 0.5 + [-2 3];

X = [X1; X2; X3];
y = [ones(n_per_class, 1); 2*ones(n_per_class, 1); 3*ones(n_per_class, 1)];

fprintf('Data: %d samples, %d features, %d classes\n', ...
    size(X,1), size(X,2), numel(unique(y)));

%% 2. Split data
cv = cvpartition(y, 'HoldOut', 0.3);
X_train = X(cv.training, :); y_train = y(cv.training);
X_test  = X(cv.test, :);     y_test  = y(cv.test);

fprintf('Train: %d, Test: %d\n', size(X_train,1), size(X_test,1));

%% 3. Train model (SVM / KNN / Tree)
% SVM classifier
if exist('fitcecoc', 'file')
    model = fitcecoc(X_train, y_train);
    model_name = 'SVM (ECOC)';
else
    % Fallback: KNN
    model = fitcknn(X_train, y_train, 'NumNeighbors', 5);
    model_name = 'k-NN (k=5)';
end

fprintf('Model: %s\n', model_name);

%% 4. Evaluate
y_pred = predict(model, X_test);
accuracy = sum(y_pred == y_test) / numel(y_test) * 100;
confmat = confusionmat(y_test, y_pred);

fprintf('\nResults:\n');
fprintf('  Accuracy: %.1f%%\n', accuracy);
fprintf('  Confusion matrix:\n');
disp(confmat);

%% 5. Visualize decision boundary
figure('Name', 'ML Classification', 'Position', [100 100 800 600]);

% Compute decision boundary
x1_range = linspace(min(X(:,1))-1, max(X(:,1))+1, 100);
x2_range = linspace(min(X(:,2))-1, max(X(:,2))+1, 100);
[x1_grid, x2_grid] = meshgrid(x1_range, x2_range);
X_grid = [x1_grid(:), x2_grid(:)];
y_grid = predict(model, X_grid);
y_grid = reshape(y_grid, size(x1_grid));

% Plot boundary
contourf(x1_grid, x2_grid, y_grid, 'LineStyle', 'none', 'FaceAlpha', 0.4);
hold on;

% Plot data points
colors = lines(3);
for k = 1:3
    scatter(X(y==k,1), X(y==k,2), 20, colors(k,:), 'filled', ...
        'DisplayName', sprintf('Class %d', k));
end

xlabel('Feature 1'); ylabel('Feature 2');
legend('Location', 'best');
title(sprintf('%s: %.1f%% accuracy', model_name, accuracy));
colorbar('off');

saveas(gcf, 'ml_results.png'); close(gcf);
fprintf('\nDone. Results saved to ml_results.png\n');

function result = cli_mat(action, filepath, varargin)
% CLI_MAT .mat 文件操作
%   CLI: ml mat <action> <file.mat> [args]
%   actions: info, list, export, merge, compare

    if nargin < 2
        error('Need action and filepath. ml mat list file.mat');
    end

    switch lower(action)
        case {'info', 'list'}
            result = mat_info(filepath);
        case 'export'
            varname = '';
            fmt = 'csv';
            outfile = '';
            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case '--var', varname = varargin{i+1};
                    case '--fmt', fmt = varargin{i+1};
                    case '--out', outfile = varargin{i+1};
                end
            end
            result = mat_export(filepath, varname, fmt, outfile);
        case 'merge'
            files = {filepath, varargin{:}};
            outfile = 'merged.mat';
            result = mat_merge(files, outfile);
        case 'compare'
            file2 = '';
            if ~isempty(varargin), file2 = varargin{1}; end
            result = mat_compare(filepath, file2);
        otherwise
            error('Unknown action: %s. Use: info, list, export, merge, compare', action);
    end
end

function result = mat_info(filepath)
    if ~exist(filepath, 'file')
        error('File not found: %s', filepath);
    end

    info = whos('-file', filepath);
    result = struct();
    result.file = filepath;
    result.n_vars = numel(info);
    result.variables = {};

    total_bytes = 0;
    for k = 1:numel(info)
        v = struct();
        v.name = info(k).name;
        v.size = info(k).size;
        v.bytes = info(k).bytes;
        v.class = info(k).class;
        if info(k).complex, v.class = [v.class ' (complex)']; end
        if info(k).sparse, v.class = [v.class ' (sparse)']; end
        result.variables{k} = v;
        total_bytes = total_bytes + info(k).bytes;
    end
    result.total_size_bytes = total_bytes;
    result.total_size_mb = total_bytes / 1e6;
end

function result = mat_export(filepath, varname, fmt, outfile)
    data = load(filepath);
    if isempty(varname)
        fns = fieldnames(data);
        varname = fns{1};
    end
    if ~isfield(data, varname)
        error('Variable %s not found in %s', varname, filepath);
    end
    var = data.(varname);

    if isempty(outfile)
        outfile = [varname, '.', fmt];
    end

    switch lower(fmt)
        case 'csv'
            if istable(var)
                writetable(var, outfile);
            else
                writematrix(var, outfile);
            end
        case 'json'
            s = jsonencode(var);
            fid = fopen(outfile, 'w');
            fprintf(fid, '%s', s);
            fclose(fid);
        case 'txt'
            if istable(var)
                writetable(var, outfile, 'Delimiter', '\t');
            else
                writematrix(var, outfile, 'Delimiter', '\t');
            end
        otherwise
            error('Unsupported format: %s. Use: csv, json, txt', fmt);
    end

    result = struct();
    result.exported = varname;
    result.format = fmt;
    result.file = outfile;
    finfo = dir(outfile);
    result.size_bytes = finfo.bytes;
end

function result = mat_merge(files, outfile)
    merged = struct();
    count = 0;
    for k = 1:numel(files)
        if ~exist(files{k}, 'file')
            warning('Skipping missing: %s', files{k});
            continue;
        end
        data = load(files{k});
        fns = fieldnames(data);
        for j = 1:numel(fns)
            merged.(fns{j}) = data.(fns{j});
            count = count + 1;
        end
    end
    save(outfile, '-struct', 'merged');
    result = struct();
    result.merged_files = numel(files);
    result.total_vars = count;
    result.output = outfile;
end

function result = mat_compare(file1, file2)
    if isempty(file2)
        error('Need second file for comparison. ml mat compare a.mat b.mat');
    end
    d1 = load(file1);
    d2 = load(file2);
    fns1 = fieldnames(d1);
    fns2 = fieldnames(d2);

    result = struct();
    result.file1 = file1;
    result.file2 = file2;
    result.vars_only_in_1 = setdiff(fns1, fns2);
    result.vars_only_in_2 = setdiff(fns2, fns1);
    result.common = intersect(fns1, fns2);
    result.n_common = numel(result.common);
    result.diffs = {};

    for k = 1:numel(result.common)
        fn = result.common{k};
        v1 = d1.(fn);
        v2 = d2.(fn);
        if isequal(v1, v2)
            continue;
        end
        diff_info = struct();
        diff_info.variable = fn;
        diff_info.class1 = class(v1);
        diff_info.class2 = class(v2);
        if isnumeric(v1) && isnumeric(v2) && isequal(size(v1), size(v2))
            diff_info.max_abs_diff = max(abs(double(v1(:)) - double(v2(:))));
        end
        result.diffs{end+1} = diff_info;
    end
    result.n_diffs = numel(result.diffs);
end

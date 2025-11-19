function create_para_file(subj_data, output_filename)
% CREATE_PARA_FILE Extract onsets and create PARA file for langloc
%
% Usage:
%   create_para_file(subj_data, output_filename)
%
% Input:
%   subj_data       - Structure with .results field containing 69x5 cell array
%   output_filename - Output path for PARA file (default: 'para.txt')
%
% Output:
%   Writes PARA file with onsets, condition names (in specified order), and durations
%
% Expected output format:
%   #onsets
%   onset condition_id
%   ...
%   #names
%   HNW ENW NSOM HF EF
%   #durations
%   duration1 duration2 duration3 duration4 duration5

    if nargin < 2
        output_filename = 'para.txt';
    end
    
    % Define condition order and mapping
    COND_NAMES = {'HNW', 'ENW', 'NSOM', 'HF', 'EF'};
    COND_IDS = containers.Map(COND_NAMES, {1, 2, 3, 4, 5});
    
    results = subj_data.results;
    
    % Initialize storage for onsets
    onsets = [];
    condition_ids = [];
    
    % Step 1: Process results to extract onsets
    hnw_block_active = false;
    enw_block_active = false;
    
    for i = 1:size(results, 1)
        cond = results{i, 2};
        onset = results{i, 4};
        
        % Skip FIX
        if strcmp(cond, 'FIX')
            hnw_block_active = false;
            enw_block_active = false;
            continue;
        end
        
        % Skip instruction markers (anything ending in '_instr')
        if endsWith(cond, '_instr')
            base_cond = cond(1:end-5);
            if strcmp(base_cond, 'HNW')
                hnw_block_active = false;
            elseif strcmp(base_cond, 'ENW')
                enw_block_active = false;
            end
            continue;
        end

        if endsWith(cond, 'instr')
            % base_cond = cond(1:end-5);
            % if strcmp(base_cond, 'HNW')
            %     hnw_block_active = false;
            % elseif strcmp(base_cond, 'ENW')
            %     enw_block_active = false;
            % end
            continue;
        end
        
        % Extract base condition name
        base_cond = cond;
        
        % For ENW and HNW, only take the first value in each block
        if strcmp(base_cond, 'HNW')
            if ~hnw_block_active
                onsets = [onsets; onset];
                condition_ids = [condition_ids; COND_IDS(base_cond)];
                hnw_block_active = true;
            end
        elseif strcmp(base_cond, 'ENW')
            if ~enw_block_active
                onsets = [onsets; onset];
                condition_ids = [condition_ids; COND_IDS(base_cond)];
                enw_block_active = true;
            end
        else
            % For other conditions (EF, NSOM, HF), take all values
            onsets = [onsets; onset];
            condition_ids = [condition_ids; COND_IDS(base_cond)];
        end
    end
    
    % Step 2: Calculate durations between blocks (inter-block intervals)
    % Average duration per condition based on inter-block spacing
    num_trials = length(onsets);
    condition_durations = zeros(1, 5);
    condition_counts = zeros(1, 5);
    
    % Calculate average inter-onset interval for each condition
    for i = 1:num_trials - 1
        next_cond_id = condition_ids(i+1);
        current_cond_id = condition_ids(i);
        
        % Only accumulate if different conditions (block transition)
        if current_cond_id ~= next_cond_id
            interval = onsets(i+1) - onsets(i);
            condition_durations(current_cond_id) = condition_durations(current_cond_id) + interval;
            condition_counts(current_cond_id) = condition_counts(current_cond_id) + 1;
        end
    end
    
    % Average the durations per condition
    for i = 1:5
        if condition_counts(i) > 0
            condition_durations(i) = round(condition_durations(i) / condition_counts(i));
        else
            condition_durations(i) = 15; % Default
        end
    end
    
    % Step 3: Write PARA file
    fid = fopen(output_filename, 'w');
    
    if fid == -1
        error('Cannot open file %s for writing', output_filename);
    end
    
    % Write #onsets section
    fprintf(fid, '#onsets\n');
    for i = 1:length(onsets)
        fprintf(fid, '%.0f %d\n', onsets(i), condition_ids(i));
    end
    
    % Write #names section
    fprintf(fid, '#names\n');
    for i = 1:length(COND_NAMES)
        if i < length(COND_NAMES)
            fprintf(fid, '%s ', COND_NAMES{i});
        else
            fprintf(fid, '%s\n', COND_NAMES{i});
        end
    end
    
    % Write #durations section
    fprintf(fid, '#durations\n');
    for i = 1:length(COND_NAMES)
        if i < length(COND_NAMES)
            fprintf(fid, '%.0f ', condition_durations(i));
        else
            fprintf(fid, '%.0f\n', condition_durations(i));
        end
    end
    
    fclose(fid);
    
    % Display summary
    fprintf('\nPARA file written: %s\n', output_filename);
    fprintf('Number of onsets: %d\n', length(onsets));
    fprintf('Condition order: %s\n', strjoin(COND_NAMES, ', '));
    fprintf('\nOnsets by condition:\n');
    for cond_id = 1:5
        count = sum(condition_ids == cond_id);
        fprintf('  %s (%d): %d instances\n', COND_NAMES{cond_id}, cond_id, count);
    end
    fprintf('\nEstimated block durations (seconds):\n');
    for i = 1:5
        fprintf('  %s: %.0f\n', COND_NAMES{i}, condition_durations(i));
    end

end

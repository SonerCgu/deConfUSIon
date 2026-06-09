function displayName = HUMOR_display_from_file_context(matFile, fallbackStem)
% Build readable name for saved/lazy preprocessing files when metadata is bad.
% Preprocessing files are NEVER called raw.

if nargin < 1, matFile = ''; end
if nargin < 2, fallbackStem = ''; end
try, matFile = char(matFile); catch, matFile = ''; end
try, fallbackStem = char(fallbackStem); catch, fallbackStem = ''; end

[folder,stem] = fileparts(matFile);
if isempty(fallbackStem), fallbackStem = stem; end
combo = [fallbackStem '_' folder];
lowCombo = lower(combo);
parts = {};

an = regexp(combo,'B6J[_-](\d{3,6})','tokens','once');
if isempty(an), an = regexp(combo,'[_-](\d{3,6})[_-]Session','tokens','once'); end
if isempty(an), an = regexp(combo,'[_-](\d{3,6})[_-]scan','tokens','once'); end
if ~isempty(an), parts{end+1} = an{1}; end

sess = regexp(folder,'Session[_-]?0*([0-9]+)','tokens','once');
if ~isempty(sess), parts{end+1} = sprintf('sess%03d',str2double(sess{1})); end

sl = regexp(combo,'Slice0*([0-9]+)of0*([0-9]+)','tokens','once');
if isempty(sl), sl = regexp(combo,'sl0*([0-9]+)of0*([0-9]+)','tokens','once'); end
if ~isempty(sl), parts{end+1} = sprintf('sl%03dof%03d',str2double(sl{1}),str2double(sl{2})); end

isPreproc = HUMOR_is_preproc_mat_path(matFile);
ops = {};

% Important rule: processed files in SplitMotor/Preprocessing are motor-derived, not raw.
if isPreproc && (~isempty(strfind(lowCombo,'splitmotor')) || ~isempty(strfind(lowCombo,'_motor')))
    ops{end+1} = 'motor';
end

tok = regexp(fallbackStem,'imreg[^_]*_?(med|median)?_?n\d+','match','once');
if ~isempty(tok), ops{end+1} = regexprep(tok,'median','med','ignorecase'); end
tok = regexp(fallbackStem,'BPF[^_]*to[^_]*Hz_o\d+|LPF[^_]*Hz_o\d+|HPF[^_]*Hz_o\d+','match','once');
if ~isempty(tok), ops{end+1} = tok; end
tok = regexp(fallbackStem,'tsmooth_[^_]+s|temporalSmooth_[^_]+s','match','once');
if ~isempty(tok), ops{end+1} = regexprep(tok,'temporalSmooth_','tsmooth_','ignorecase'); end
tok = regexp(fallbackStem,'submean[^_]*_nsub\d+|subsample_[^_]*_nsub\d+','match','once');
if ~isempty(tok), ops{end+1} = regexprep(tok,'subsample_mean_','submean_','ignorecase'); end
tok = regexp(fallbackStem,'pca[^_]*_?dropPC[^_]*|dropPC[^_]*','match','once');
if ~isempty(tok)
    if isempty(strfind(lower(tok),'pca')), tok = ['pca_' tok]; end
    ops{end+1} = tok;
end
tok = regexp(fallbackStem,'ica[^_]*_?dropIC[^_]*|dropIC[^_]*','match','once');
if ~isempty(tok)
    if isempty(strfind(lower(tok),'ica')), tok = ['ica_' tok]; end
    ops{end+1} = tok;
end

if isempty(parts)
    base = 'dataset';
else
    base = strjoin(parts,'_');
end

if isPreproc
    if isempty(ops)
        % Still do NOT call it raw. For SplitMotor this becomes motor; otherwise processed.
        if ~isempty(strfind(lowCombo,'splitmotor'))
            ops{end+1} = 'motor';
        else
            ops{end+1} = 'processed';
        end
    end
else
    ops{end+1} = 'raw';
end

ts = regexp(fallbackStem,'\d{8}_\d{6}','match','once');
displayName = strjoin([{base} ops],'_');
if ~isempty(ts), displayName = [displayName '_' ts]; end
displayName = HUMOR_compact_chain_name(displayName);
end

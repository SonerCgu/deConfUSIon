function displayName = deConfUSIon_display_from_file_context(matFile, fallbackStem)
% Build readable name for saved/lazy preprocessing files when metadata is missing.
if nargin < 1, matFile = ''; end
if nargin < 2 || isempty(fallbackStem), fallbackStem = ''; end
try, matFile = char(matFile); catch, matFile = ''; end
try, fallbackStem = char(fallbackStem); catch, fallbackStem = ''; end
[folder,stem] = fileparts(matFile);
if isempty(fallbackStem), fallbackStem = stem; end
combo = [fallbackStem '_' folder];
low = lower(combo);
parts = {};
an = regexp(combo,'B6J[_-]?(\d{3,6})','tokens','once');
if isempty(an), an = regexp(combo,'[_-](\d{3,6})[_-]Session','tokens','once'); end
if isempty(an), an = regexp(combo,'[_-](\d{3,6})[_-]scan','tokens','once'); end
if ~isempty(an), parts{end+1} = an{1}; end
sess = regexp(folder,'Session[_-]?0*([0-9]+)','tokens','once');
if ~isempty(sess), parts{end+1} = sprintf('sess%03d',str2double(sess{1})); end
sl = regexp(combo,'Slice0*([0-9]+)of0*([0-9]+)','tokens','once');
if isempty(sl), sl = regexp(combo,'sl0*([0-9]+)of0*([0-9]+)','tokens','once'); end
if ~isempty(sl), parts{end+1} = sprintf('sl%03dof%03d',str2double(sl{1}),str2double(sl{2})); end
ops = {};
if ~isempty(strfind(low,'splitmotor')) || ~isempty(strfind(low,'_motor')), ops{end+1} = 'motor'; end
tok = regexp(fallbackStem,'imreg[^_]*_?(med|median|mean)?_?n\d+','match','once');
if ~isempty(tok), ops{end+1} = regexprep(tok,'median','med','ignorecase'); end
tok = regexp(fallbackStem,'BPF[^_]*to[^_]*Hz_o\d+|LPF[^_]*Hz_o\d+|HPF[^_]*Hz_o\d+','match','once');
if ~isempty(tok), ops{end+1} = tok; end
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
if isempty(parts), base = 'dataset'; else, base = strjoin(parts,'_'); end
if isempty(ops)
    if ~isempty(strfind(lower(folder),'preprocessing')) || ~isempty(strfind(lower(folder),'splitmotor'))
        ops{end+1} = 'processed';
    else
        ops{end+1} = 'raw';
    end
end
ts = regexp(fallbackStem,'\d{8}_\d{6}','match','once');
displayName = strjoin([{base} ops],'_');
if ~isempty(ts), displayName = [displayName '_' ts]; end
displayName = regexprep(displayName,'_+','_');
displayName = regexprep(displayName,'^_+|_+$','');
end

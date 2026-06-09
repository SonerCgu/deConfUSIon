function studio = HUMOR_fix_studio_dataset_names(studio)
% Fix visible names in studio.datasets at dropdown refresh time.

if nargin < 1 || ~isstruct(studio), return; end
if ~isfield(studio,'datasets') || isempty(studio.datasets), return; end

keys = fieldnames(studio.datasets);
for i = 1:numel(keys)
    key = keys{i};
    try
        d = studio.datasets.(key);
        if ~isstruct(d), continue; end

        matFile = local_mat_path(d);
        seed = key;
        if isfield(d,'HUMOR_fullDisplayName') && ~isempty(d.HUMOR_fullDisplayName)
            seed = d.HUMOR_fullDisplayName;
        elseif isfield(d,'displayNameFull') && ~isempty(d.displayNameFull)
            seed = d.displayNameFull;
        elseif isfield(d,'preprocDisplayName') && ~isempty(d.preprocDisplayName)
            seed = d.preprocDisplayName;
        end

        dataForName = d;
        if ~isempty(matFile) && exist(matFile,'file') == 2
            try
                info = whos('-file',matFile);
                names = {info.name};
                if ismember('HUMOR_fullDisplayName',names) || ismember('displayNameFull',names) || ismember('preprocDisplayName',names)
                    vars = {};
                    if ismember('HUMOR_fullDisplayName',names), vars{end+1} = 'HUMOR_fullDisplayName'; end %#ok<AGROW>
                    if ismember('displayNameFull',names), vars{end+1} = 'displayNameFull'; end %#ok<AGROW>
                    if ismember('preprocDisplayName',names), vars{end+1} = 'preprocDisplayName'; end %#ok<AGROW>
                    S = load(matFile,vars{:});
                    if isfield(S,'HUMOR_fullDisplayName') && ~isempty(S.HUMOR_fullDisplayName)
                        seed = S.HUMOR_fullDisplayName;
                    elseif isfield(S,'displayNameFull') && ~isempty(S.displayNameFull)
                        seed = S.displayNameFull;
                    elseif isfield(S,'preprocDisplayName') && ~isempty(S.preprocDisplayName)
                        seed = S.preprocDisplayName;
                    end
                end
                if local_bad(seed) && ismember('newData',names)
                    S2 = load(matFile,'newData');
                    if isfield(S2,'newData') && isstruct(S2.newData)
                        dataForName = S2.newData;
                    end
                end
            catch
            end
        end

        fullName = HUMOR_display_name_from_sources(seed,dataForName,matFile);
        studio.datasets.(key).HUMOR_fullDisplayName = fullName;
        studio.datasets.(key).displayNameFull = fullName;
        studio.datasets.(key).preprocDisplayName = fullName;
    catch
    end
end
end

function tf = local_bad(s)
try, s = char(s); catch, tf = true; return; end
low = lower(s);
tf = false;
if isempty(s), tf = true; return; end
if ~isempty(strfind(s,'...')), tf = true; return; end
if ~isempty(strfind(low,'preproc_preproc')), tf = true; return; end
if ~isempty(regexp(low,'(^|_)preproc_[0-9]','once')), tf = true; return; end
if ~isempty(regexp(low,'_[0-9a-f]{8}($|_)','once')), tf = true; return; end
end

function p = local_mat_path(d)
p = '';
fields = {'lazyFile','savedFile','matFile','sourceFile','filePath'};
for k = 1:numel(fields)
    f = fields{k};
    if isfield(d,f) && ~isempty(d.(f))
        try
            candidate = char(d.(f));
            if exist(candidate,'file') == 2 && ~isempty(regexpi(candidate,'\.mat$'))
                p = candidate;
                return;
            end
        catch
        end
    end
end
end

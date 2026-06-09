function out = deConfUSIon_FC_find_stepmotor_txt_names(folder)
% deConfUSIon_FC_find_stepmotor_txt_names
% Recursively finds readable atlas/region-name TXT/CSV/TSV/MAT files for step-motor FC.

out = struct();
out.folder = folder;
out.names = struct('labels',[] ,'names',{{}});
out.files = {};
out.bestFile = '';
out.summary = '';

if nargin < 1 || isempty(folder) || exist(folder,'dir') ~= 7
    return;
end

files = localFiles(folder);
cand = {};
score = [];

for i = 1:numel(files)
    f = files{i};
    [~,nm,ext] = fileparts(f);
    ext = lower(ext);
    if ~(strcmp(ext,'.txt') || strcmp(ext,'.csv') || strcmp(ext,'.tsv') || strcmp(ext,'.mat'))
        continue;
    end

    low = lower([nm ext]);
    sc = 0;
    if ~isempty(strfind(low,'atlasregions_slice')), sc = sc + 1000; end
    if ~isempty(strfind(low,'atlasregions')),       sc = sc + 900;  end
    if ~isempty(strfind(low,'atlas_regions')),      sc = sc + 850;  end
    if ~isempty(strfind(low,'regiontable')),        sc = sc + 800;  end
    if ~isempty(strfind(low,'region_table')),       sc = sc + 800;  end
    if ~isempty(strfind(low,'regionnames')),        sc = sc + 700;  end
    if ~isempty(strfind(low,'region_names')),       sc = sc + 700;  end
    if ~isempty(strfind(low,'roinames')),           sc = sc + 650;  end
    if ~isempty(strfind(low,'roi_names')),          sc = sc + 650;  end
    if ~isempty(strfind(low,'inforegions')),        sc = sc + 600;  end
    if ~isempty(strfind(low,'labels')),             sc = sc + 300;  end
    if ~isempty(strfind(low,'names')),              sc = sc + 300;  end
    if ~isempty(strfind(low,'functionalconnectivity')), sc = sc - 1000; end
    if ~isempty(strfind(low,'fc_groupbundle')),         sc = sc - 1000; end

    if sc > 0
        T = localReadRegionNames(f);
        if ~isempty(T.labels)
            cand{end+1} = f; %#ok<AGROW>
            score(end+1) = sc + numel(T.labels); %#ok<AGROW>
        end
    end
end

if isempty(cand)
    out.summary = sprintf('No readable region-name files found recursively under: %s',folder);
    return;
end

[~,ord] = sort(score,'descend');
cand = cand(ord);

Tall = struct('labels',[] ,'names',{{}});
for i = 1:numel(cand)
    T = localReadRegionNames(cand{i});
    Tall = localMerge(Tall,T);
end

out.names = Tall;
out.files = cand;
out.bestFile = cand{1};
out.summary = sprintf('Loaded %d unique labels from %d recursive file(s). Best: %s', ...
    numel(out.names.labels), numel(out.files), localShort(out.bestFile));
end

function files = localFiles(folder)
files = {};
d = dir(folder);
for i = 1:numel(d)
    nm = d(i).name;
    if strcmp(nm,'.') || strcmp(nm,'..'), continue; end
    f = fullfile(folder,nm);
    if d(i).isdir
        sub = localFiles(f);
        files = [files sub]; %#ok<AGROW>
    else
        files{end+1} = f; %#ok<AGROW>
    end
end
end

function T = localReadRegionNames(f)
T = struct('labels',[] ,'names',{{}});
[~,~,ext] = fileparts(f);
ext = lower(ext);

try
    if strcmp(ext,'.mat')
        S = load(f);
        fn = fieldnames(S);
        for ii = 1:numel(fn)
            x = S.(fn{ii});
            if isstruct(x) && isfield(x,'infoRegions')
                x = x.infoRegions;
            end
            if isstruct(x)
                T = localFromStruct(x);
                if ~isempty(T.labels), return; end
            end
            if istable(x)
                T = localFromTable(x);
                if ~isempty(T.labels), return; end
            end
        end
        return;
    end
catch
end

try
    txt = fileread(f);
catch
    return;
end

lines = regexp(txt,'\r\n|\n|\r','split');
for i = 1:numel(lines)
    s = strtrim(lines{i});
    if isempty(s), continue; end
    if numel(s) >= 1 && (s(1)=='#' || s(1)=='%')
        continue;
    end

    s = regexprep(s,'//.*$','');
    s = strtrim(s);
    if isempty(s), continue; end

    tok = regexp(s,'^\s*(\d+)\s*[,;\t ]+\s*(.+?)\s*$','tokens','once');
    if isempty(tok)
        tok = regexp(s,'^\s*([A-Za-z][A-Za-z0-9_\-\(\)/\.]*)\s*[,;\t ]+\s*(\d+)\s*$','tokens','once');
        if ~isempty(tok)
            lab = str2double(tok{2});
            name = tok{1};
        else
            continue;
        end
    else
        lab = str2double(tok{1});
        name = tok{2};
    end

    if isfinite(lab)
        T.labels(end+1,1) = lab; %#ok<AGROW>
        T.names{end+1,1} = strtrim(name); %#ok<AGROW>
    end
end

T = localUnique(T);
end

function T = localFromStruct(S)
T = struct('labels',[] ,'names',{{}});
labelFields = {'labels','label','id','ID','idx','index','num','number'};
nameFields  = {'names','name','acr','acronym','structure_name','region','regions'};
lf = ''; nf = '';
for i = 1:numel(labelFields)
    if isfield(S,labelFields{i}), lf = labelFields{i}; break; end
end
for i = 1:numel(nameFields)
    if isfield(S,nameFields{i}), nf = nameFields{i}; break; end
end
if isempty(lf) || isempty(nf), return; end
labels = S.(lf); names = S.(nf);
if iscell(labels), labels = cellfun(@str2double,labels); end
if ischar(names), names = cellstr(names); end
labels = double(labels(:));
if iscell(names)
    names = names(:);
else
    try, names = cellstr(names); catch, return; end
end
n = min(numel(labels),numel(names));
T.labels = labels(1:n);
T.names = names(1:n);
T = localUnique(T);
end

function T = localFromTable(T0)
T = struct('labels',[] ,'names',{{}});
vars = T0.Properties.VariableNames;
lf = ''; nf = '';
for i = 1:numel(vars)
    low = lower(vars{i});
    if isempty(lf) && (~isempty(strfind(low,'label')) || strcmp(low,'id') || ~isempty(strfind(low,'index')))
        lf = vars{i};
    end
    if isempty(nf) && (~isempty(strfind(low,'name')) || ~isempty(strfind(low,'acr')) || ~isempty(strfind(low,'region')))
        nf = vars{i};
    end
end
if isempty(lf) || isempty(nf), return; end
labels = T0.(lf); names = T0.(nf);
if iscell(labels), labels = cellfun(@str2double,labels); end
if ischar(names), names = cellstr(names); end
labels = double(labels(:));
if iscell(names), names = names(:); else, names = cellstr(names); end
n = min(numel(labels),numel(names));
T.labels = labels(1:n);
T.names = names(1:n);
T = localUnique(T);
end

function T = localMerge(A,B)
T = A;
if isempty(B.labels), return; end
for i = 1:numel(B.labels)
    lab = double(B.labels(i));
    nm = B.names{i};
    if isempty(T.labels) || ~any(double(T.labels(:)) == lab)
        T.labels(end+1,1) = lab; %#ok<AGROW>
        T.names{end+1,1} = nm; %#ok<AGROW>
    end
end
end

function T = localUnique(T)
if isempty(T.labels), return; end
[u,ia] = unique(double(T.labels(:)),'stable');
T.labels = u(:);
T.names = T.names(ia);
T.names = T.names(:);
end

function nm = localShort(f)
[~,a,b] = fileparts(f);
nm = [a b];
end

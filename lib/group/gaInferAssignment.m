function [group,condition,reason]=gaInferAssignment(file)
% Prefer ROI metadata to file name, then inspect parents nearest-first.
% Never infer a treatment from an experiment folder naming both treatments.
group='Unassigned'; condition='Unassigned'; reason='No unambiguous ROI or treatment label';
file=char(file); labels={};
[~,~,ext]=fileparts(file);
if strcmpi(ext,'.txt') && isfile(file)
    fid=fopen(file,'rt');
    if fid>=0
        cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
        for i=1:512
            line=fgetl(fid); if ~ischar(line), break; end
            if ~isempty(regexpi(line,'^#\s*columns\s*:','once')), break; end
            token=regexpi(line,'^#\s*ROI_LABEL\s*:\s*(.*)$','tokens','once');
            if ~isempty(token), labels{end+1}=token{1}; end %#ok<AGROW>
            token=regexpi(line,'^#\s*AutomaticROISelection\s*:\s*(.*)$','tokens','once');
            if ~isempty(token)
                try
                    a=jsondecode(token{1});
                    if isfield(a,'role'), labels{end+1}=char(a.role); end %#ok<AGROW>
                catch
                    % Older/manual exports may have no valid automatic metadata.
                end
            end
        end
    end
end
hits=[false false];
for i=1:numel(labels), hits=hits|classify(labels{i}); end
if any(hits)
    source='ROI header';
else
    % Both separators are recognized even when reading a foreign-platform path.
    parts=regexp(file,'[\\/]','split');
    if ~isempty(parts), [~,parts{end}]=fileparts(parts{end}); end
    source='Filename / nearest labeled folder';
    for i=numel(parts):-1:1
        hits=classify(parts{i});
        if any(hits), break; end
    end
end
if all(hits)
    reason=['Conflicting Target/PACAP and Control/Vehicle labels in ' source];
elseif hits(1)
    group='PACAP'; condition='CondA'; reason=[source ': Target / PACAP'];
elseif hits(2)
    group='Control'; condition='CondB'; reason=[source ': Control / Ringer / Vehicle'];
end
end

function hit=classify(text)
text=upper(strtrim(char(text)));
a='TARGET|PACAP|GROUP[ _-]*A|COND(?:ITION)?[ _-]*A';
b='CTRL|CONTROL|VEHICLE|VEH|RINGER|PBS|ACSF|GROUP[ _-]*B|COND(?:ITION)?[ _-]*B';
hit=[~isempty(regexp(text,['(^|[^A-Z0-9])(' a ')(?=$|[^A-Z0-9])'],'once')), ...
     ~isempty(regexp(text,['(^|[^A-Z0-9])(' b ')(?=$|[^A-Z0-9])'],'once'))];
% Common experiment folder names have no separator around "vs".
if ~isempty(regexp(text,'PACAP[ _-]*VS[ _-]*(RINGER|VEHICLE|CONTROL)|(?:RINGER|VEHICLE|CONTROL)[ _-]*VS[ _-]*PACAP','once'))
    hit=[true true];
end
if strcmp(text,'A'), hit=[true false]; elseif strcmp(text,'B'), hit=[false true]; end
end

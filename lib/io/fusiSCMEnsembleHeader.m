function header=fusiSCMEnsembleHeader(fid,findTable)
% Fast access to the fixed SCM ensemble schema, including old huge audits.
% ROI_MEMBERS is audit-only JSON. Assignment and numeric columns are outside
% it, so neither importing a role nor reading its trace needs that payload.
if nargin<2,findTable=true;end
header=struct('matched',false,'tableFound',false,'labels',{{}},'prefix','', ...
    'baselineSec',[NaN NaN],'isRebased',false);
origin=ftell(fid);prefix=fread(fid,65536,'*char')';
marker=regexp(prefix,'(?:^|[\r\n])#[ \t]*ROI_MEMBERS[ \t]*:','start','once');
if isempty(marker)||isempty(regexp(prefix,'^# ROI export from SCM_gui: selected ROI ensemble[\r\n]','once'))
    fseek(fid,origin,'bof');return;
end
prefix=prefix(1:marker-1);header.matched=true;header.prefix=prefix;
tokens=regexpi(prefix,'(?:^|[\r\n])#[ \t]*ROI_LABEL[ \t]*:[ \t]*([^\r\n]*)','tokens');
header.labels=cellfun(@(x)x{1},tokens,'UniformOutput',false);
token=regexpi(prefix,'(?:^|[\r\n])#[ \t]*BaselineWindow:[ \t]*([^\r\n]+)','tokens','once');
if ~isempty(token)
    nums=sscanf(strrep(strrep(token{1},'-',' '),',',' '),'%f');
    if numel(nums)>=2,header.baselineSec=double(nums(1:2))';end
end
token=regexpi(prefix,'(?:^|[\r\n])#[ \t]*PSC_REBASED:[ \t]*([a-z0-9]+)','tokens','once');
if ~isempty(token),header.isRebased=any(strcmpi(token{1},{'1','true','yes','y'}));end
if ~findTable,return;end
fseek(fid,0,'eof');bytes=ftell(fid);
% Most real exports have only a few kilobytes of trace after many megabytes
% of old audit JSON. Grow the tail window only for long numeric tables.
window=min(bytes,65536);
while true
    fseek(fid,bytes-window,'bof');tail=fread(fid,window,'*char')';
    [~,last]=regexpi(tail,'(?:^|[\r\n])#[ \t]*columns[ \t]*:[^\r\n]*psc[^\r\n]*[\r\n]+','start','end','once');
    if ~isempty(last)
        fseek(fid,bytes-window+last,'bof');header.tableFound=true;return;
    end
    if window>=bytes||window>=4*1024^2,break;end
    window=min(bytes,window*2);
end
fseek(fid,origin,'bof');
end

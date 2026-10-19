function studio=studioSaveDataset(fig,studio,key,progress)
% Retain completed analysis in Studio before disk I/O can fail or dispatch UI.
data=studio.datasets.(key);
if isfield(data,'deconfPscKey')
    data=rmfield(data,intersect(fieldnames(data),{'PSC','bg','I1','deconfPscKey','deconfPscDatasetKey'}));
end
assert(isfield(data,'I') && ~isempty(data.I),'deConfUSIon:EmptySave','Completed analysis has no image data.');
assert(isfield(data,'savedFile') && ~isempty(data.savedFile),'deConfUSIon:SavePath','Completed analysis has no output path.');
data.isLazy=false;
studio.datasets.(key)=data;
guidata(fig,studio);
if nargin<4,progress=[];end
DataIO('save',data.savedFile,struct('newData',data),progress);
end

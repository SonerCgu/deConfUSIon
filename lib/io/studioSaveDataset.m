function studio=studioSaveDataset(fig,studio,key)
% Retain completed analysis in Studio before disk I/O can fail or dispatch UI.
data=studio.datasets.(key);
assert(isfield(data,'I') && ~isempty(data.I),'deConfUSIon:EmptySave','Completed analysis has no image data.');
assert(isfield(data,'savedFile') && ~isempty(data.savedFile),'deConfUSIon:SavePath','Completed analysis has no output path.');
data.isLazy=false;
studio.datasets.(key)=data;
guidata(fig,studio);
DataIO('save',data.savedFile,struct('newData',data));
end

function file=scmExportNote(folder,label,note,filename)
% A human-readable companion; never overwrite an existing user's notes.
if nargin<3,note='';end
if nargin<4,filename='note.txt';end
file=fullfile(folder,filename);if isfile(file),return;end
fid=fopen(file,'w','n','UTF-8');assert(fid>=0,'deConfUSIon:ExportNote','Could not create %s.',file);
guard=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'deConfUSIon ROI export notes\nDataset: %s\nCreated: %s\n\n',label,char(datetime('now')));
fprintf(fid,'%s\n',char(note));
end

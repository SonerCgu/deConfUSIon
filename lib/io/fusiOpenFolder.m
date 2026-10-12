function process=fusiOpenFolder(folder)
% Open a saved directory in Explorer, Finder or the Linux file manager.
assert(isfolder(folder),'deConfUSIon:FolderMissing','Folder is unavailable: %s',folder);
folder=char(java.io.File(char(folder)).getCanonicalPath());
args=fusiDesktopFolderCommand(folder);list=java.util.ArrayList();
for k=1:numel(args),list.add(java.lang.String(args{k}));end
builder=java.lang.ProcessBuilder(list);process=builder.start();
end

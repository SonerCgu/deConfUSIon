function file=fusiPaperMoviePath(original)
[folder,name,extension]=fileparts(original);
assert(strcmpi(extension,'.mp4'),'deConfUSIon:PaperMovie','Paper companion requires an MP4 filename.');
file=fullfile(folder,[name '_paper_ready.mp4']);
end

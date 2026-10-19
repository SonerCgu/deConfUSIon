function file=fusiPaperMoviePath(original)
[folder,name,extension]=fileparts(original);
if ispc||ismac
    assert(strcmpi(extension,'.mp4'),'deConfUSIon:PaperMovie','Paper companion requires an MP4 filename.');
    file=fullfile(folder,[name '_paper_ready.mp4']);return;
end
assert(any(strcmpi(extension,{'.mp4','.avi'})),'deConfUSIon:PaperMovie','Paper companion requires a supported movie filename.');
file=fullfile(folder,[name '_paper_ready' extension]);
end

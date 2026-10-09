function folder=fusiUniqueOutputFolder(parent,name)
% Reserve a new output directory, including two saves within one millisecond.
parent=fusiAnalysisOutputPath(parent);if ~isfolder(parent),mkdir(parent);end
folder=fullfile(parent,name);suffix=0;
while ~java.io.File(folder).mkdir()
 if ~isfolder(folder),error('deConfUSIon:OutputFolder','Could not create output folder: %s',folder);end
 suffix=suffix+1;folder=fullfile(parent,sprintf('%s_%03d',name,suffix));
end
end

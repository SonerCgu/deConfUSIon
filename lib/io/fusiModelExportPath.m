function [filename,identity]=fusiModelExportPath(par,label,extension,movieType,includeSequence)
% An explicit export creates an analysed-dataset dated output folder.
if nargin<5,includeSequence=false;end
[folder,identity]=fusiMovieExportFolder(par,label,'3DModel',42,includeSequence);
if includeSequence,label=identity.nameLabel;end
label=regexprep(char(label),'[^a-zA-Z0-9_-]+','_');
kind='model';if strcmpi(extension,'mp4')
    if strcmpi(movieType,'timeseries'),kind='PSC_time_series';elseif strcmpi(movieType,'combined'),kind='PSC_time_series_rotation';else,kind='camera_rotation';end
end
% Leave room for the companion suffix and settings sidecar on Windows.
available=240-numel(fullfile(folder,['_' kind '_paper_ready.' extension]));
label=label(1:min([48 numel(label) max(1,available)]));
label=regexprep(label,'_+$','');if isempty(label),label='scan';end
filename=fullfile(folder,[label '_' kind '.' extension]);
end

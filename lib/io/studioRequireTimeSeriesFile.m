function path=studioRequireTimeSeriesFile(path)
% Studio Load always imports a dataset, never substitutes a separate viewer.
% Keep asking for a time series if a spatial NIfTI summary was selected.
while ~isempty(path) && endsWith(lower(path),{'.nii','.nii.gz'})
    info=niftiinfo(path);
    if numel(info.ImageSize)>=4 && info.ImageSize(4)>=2, return; end
    folder=fileparts(path);
    [f,p]=uigetfile({'*.nii;*.nii.gz;*.mat','Time-series datasets (*.nii, *.nii.gz, *.mat)'}, ...
        'Selected NIfTI is a 3D summary. Choose the original 4D time series for Raw import', ...
        folder);
    if isequal(f,0), path=''; return; end
    path=fullfile(p,f);
end
end

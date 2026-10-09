function fig=openNiftiSCM(path,kind,sliceAxis)
% Import an existing 3D map into SCM without temporal renormalization.
deConfUSIon_setup();
fig=[];
if nargin<1 || isempty(path)
    [f,p]=uigetfile({'*.nii;*.nii.gz','NIfTI volumes'},'Open static volume in SCM');
    if isequal(f,0), return; end
    path=fullfile(p,f);
end
interactive=nargin<2 || isempty(kind);
if interactive
    answer=questdlg(['How should SCM interpret the stored voxel values? ' ...
        'Choose percent only if this file already contains percent signal change.'], ...
        'NIfTI map values','Signal change (%)','Image intensity','Cancel','Image intensity');
    if isempty(answer)||strcmp(answer,'Cancel'), return; end
    if strcmp(answer,'Signal change (%)'), kind='percent'; else, kind='intensity'; end
end
assert(any(strcmp(kind,{'percent','intensity'})),'deConfUSIon:StaticKind','Choose percent or intensity.');
[V,info]=readFMRINifti(path);
assert(ndims(V)<=3,'deConfUSIon:StaticDimensions','Use Studio Load for a 4D time series.');
if nargin<3 || isempty(sliceAxis)
    sliceAxis=3;
    if interactive
        sz=size(V); sz(end+1:3)=1; [~,suggested]=min(sz);
        [sliceAxis,ok]=listdlg('PromptString','Choose the native voxel axis to scroll through (no resampling)', ...
            'SelectionMode','single','InitialValue',suggested,'ListSize',[430 150], ...
            'ListString',arrayfun(@(k)sprintf('Voxel axis %d: %d slices',k,sz(k)),1:3,'UniformOutput',false));
        if ~ok, return; end
    end
end
assert(isscalar(sliceAxis)&&ismember(sliceAxis,1:3),'deConfUSIon:StaticAxis','Slice axis must be 1, 2 or 3.');
orders={[3 2 1],[3 1 2],[2 1 3]}; order=orders{sliceAxis};
par=struct('staticVolume',true,'valueKind',kind,'sourceFile',path,'niftiInfo',info,'axisPermutation',order);
% Only permute voxel axes; retain the original affine in metadata.
fig=SCM_gui(permute(V,order),[],[],par,[],[]);
end

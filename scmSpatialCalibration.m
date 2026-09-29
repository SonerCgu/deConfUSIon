function c=scmSpatialCalibration(par)
% Spacing is sampling, NOT measured acoustic resolution. Never guess units.
c=struct('spacingUm',[NaN NaN NaN],'rawSpacing',[],'source','Units unavailable; calibration required.');
nodes={par};
if isfield(par,'meta') && isstruct(par.meta)
    nodes{end+1}=par.meta;
    if isfield(par.meta,'rawMetadata') && isstruct(par.meta.rawMetadata), nodes{end+1}=par.meta.rawMetadata; end
end
% Nested vendor metadata may carry explicit units; never infer from magnitude.
for k=1:numel(nodes)
    for key={'metadata','md'}
        if isfield(nodes{k},key{1}) && isstruct(nodes{k}.(key{1})), nodes{end+1}=nodes{k}.(key{1}); end %#ok<AGROW>
    end
end
if isfield(par,'meta') && isfield(par.meta,'rawMetadata') && isfield(par.meta.rawMetadata,'permuteApplied') ...
        && ~isequal(par.meta.rawMetadata.permuteApplied,[1 2 3 4])
    c.source='Raw axes were permuted: confirm current row/column/slice spacing manually.'; return;
end
for k=1:numel(nodes)
    m=nodes{k}; v=[]; unit='';
    if isfield(m,'voxelSizeUm'), v=double(m.voxelSizeUm(:)'); unit='um';
    elseif isfield(m,'voxelSize'), v=double(m.voxelSize(:)'); end
    if isempty(v), continue; end
    if isempty(c.rawSpacing), c.rawSpacing=v; end
    for key={'voxelSizeUnit','voxelSizeUnits','spatialUnits','SpaceUnits'}
        if isempty(unit) && isfield(m,key{1}), unit=char(m.(key{1})); end
    end
    if isempty(unit) && isfield(m,'nifti') && isfield(m.nifti,'SpaceUnits'), unit=char(m.nifti.SpaceUnits); end
    % This scanner's nested native header omits units. Resolve only the
    % beamformer grids verified against the supplied sequence files, with
    % matching native dimensions; do not infer units from numeric magnitude.
    if isempty(unit) && all(isfield(m,{'imageDim','imageSize','imageType','origen','voxelSize'})) ...
            && strcmpi(char(m.imageType),'doppler')
        for profile={'matrix','linear'}
            ref=scmProbeSpacing(profile{1}); count=2+strcmp(profile{1},'matrix');
            dims=double(m.imageSize(:)');
            matches=numel(v)>=count && numel(dims)>=count && ...
                all(abs(v(1:count)-ref.rawSpacing(1:count))<1e-9) && dims(2)==ref.expectedColumns;
            if count==3, matches=matches && dims(3)==ref.expectedSlices; end
            if matches && isfield(par,'scmSizeYXZ')
                matches=isequal(dims(1:count),double(par.scmSizeYXZ(1:count)));
            end
            if matches
                c.spacingUm(1:count)=v(1:count)*1000;
                c.source=['Saved scanner voxelSize in mm, verified against ' ref.source]; return;
            end
        end
    end
    switch lower(strtrim(unit))
        case {'um','micron','microns','micrometer','micrometers'}, factor=1;
        case {'mm','millimeter','millimeters'}, factor=1000;
        case {'m','meter','meters'}, factor=1e6;
        otherwise, continue;
    end
    if numel(v)<2 || any(~isfinite(v(1:2)) | v(1:2)<=0), continue; end
    c.spacingUm(1:min(3,numel(v)))=v(1:min(3,numel(v)))*factor;
    c.source=sprintf('Metadata, array order [row column slice], unit %s.',unit); return;
end
end

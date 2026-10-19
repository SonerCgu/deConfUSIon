function [mm,source]=fusiLightSuiteSpacing(meta)
% Use explicit units or a native AUTC beamformer profile already verified by
% deConfUSIon. Never decide units from the numerical size of a spacing value.
mm=[];source='No supported physical spacing metadata found.';
nodes={meta};k=1;
while k<=numel(nodes)&&k<=30
    s=nodes{k};k=k+1;if ~isstruct(s)||~isscalar(s),continue;end
    if isfield(s,'permuteApplied')&&~isequal(s.permuteApplied,[1 2 3 4])
        source='Raw axes were permuted: confirm current row/column/slice spacing manually.';return;
    end
    % A loader permutation invalidates inherited native-axis calibration.
    if isfield(s,'rawMetadata')&&isstruct(s.rawMetadata)&&isscalar(s.rawMetadata)
        raw=s.rawMetadata;
        if isfield(raw,'permuteApplied')&&~isequal(raw.permuteApplied,[1 2 3 4])
            source='Raw axes were permuted: confirm current row/column/slice spacing manually.';return;
        end
    end
    for field={'voxelSizeMm','voxelSizeUm'}
        if ~isfield(s,field{1})||~isnumeric(s.(field{1})),continue;end
        value=s.(field{1});v=double(value(:)');
        if numel(v)==3&&all(isfinite(v)&v>0)
            mm=v;if strcmp(field{1},'voxelSizeUm'),mm=mm/1000;end
            source=['Explicit ' field{1} ' metadata, input array dimension order.'];
            if isfield(s,'spacingProvenance'),source=s.spacingProvenance;end
            return;
        end
    end
    if isfield(s,'voxelSize')&&isnumeric(s.voxelSize)
        unit='';
        for field={'voxelSizeUnit','voxelSizeUnits','spatialUnits','SpaceUnits'}
            if isfield(s,field{1})&&(ischar(s.(field{1}))||isstring(s.(field{1})))&&~isempty(s.(field{1}))
                unit=lower(strtrim(char(string(s.(field{1})))));break;
            end
        end
        unit=strrep(strrep(unit,char(181),'u'),char(956),'u');factor=[];
        if any(strcmp(unit,{'mm','millimeter','millimeters','millimetre','millimetres'})),factor=1;
        elseif any(strcmp(unit,{'um','micron','microns','micrometer','micrometers','micrometre','micrometres'})),factor=.001;
        elseif any(strcmp(unit,{'m','meter','meters','metre','metres'})),factor=1000;end
        v=double(s.voxelSize(:)');
        if ~isempty(factor)&&numel(v)==3&&all(isfinite(v)&v>0)
            mm=v*factor;source=['Explicit voxelSize units: ' unit ', input array dimension order.'];return;
        end
    end
    % Processed files and Studio datasets retain headers under these wrappers.
    for field={'rawMetadata','metadata','md','meta','newData','data','D','par','loadedPar','lightSuiteGeometry'}
        if isfield(s,field{1})&&isstruct(s.(field{1})),nodes{end+1}=s.(field{1});end %#ok<AGROW>
    end
    c=scmSpatialCalibration(struct('meta',s));
    if all(isfinite(c.spacingUm)&c.spacingUm>0),mm=c.spacingUm/1000;source=c.source;return;end
end
end

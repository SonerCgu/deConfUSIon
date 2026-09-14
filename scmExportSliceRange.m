function slices = scmExportSliceRange(firstSlice, lastSlice, nSlices)
%SCMEXPORTSLICERANGE Validate an inclusive range before creating export files.
% Slice numbers remain the original dataset indices in exported images/PPT.
validateattributes(nSlices, {'numeric'}, {'scalar','real','finite','integer','positive'}, ...
    mfilename, 'nSlices');
firstSlice = parseScalar(firstSlice);
lastSlice = parseScalar(lastSlice);
if ~isfinite(firstSlice) || ~isfinite(lastSlice) || ...
        firstSlice ~= fix(firstSlice) || lastSlice ~= fix(lastSlice) || ...
        firstSlice < 1 || lastSlice > nSlices || firstSlice > lastSlice
    error('SCM:ExportSliceRange', ...
        ['Enter whole slice numbers from 1 to %d. The first slice must be ' ...
         'less than or equal to the last slice. Both ends are included.'], nSlices);
end
slices = firstSlice:lastSlice;
end

function value = parseScalar(value)
if ischar(value) || (isstring(value) && isscalar(value))
    value = str2double(strtrim(value));
end
if ~isnumeric(value) || ~isscalar(value) || ~isreal(value)
    value = NaN;
else
    value = double(value);
end
end

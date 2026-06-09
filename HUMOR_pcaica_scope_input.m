function [dataOut, scopeInfo] = HUMOR_pcaica_scope_input(dataIn, cfg)
dataOut = dataIn;
scopeInfo = cfg;
if nargin < 2 || ~isstruct(cfg), return; end
if ~isfield(scopeInfo,'sliceSpecific'), scopeInfo.sliceSpecific = false; end
if ~scopeInfo.sliceSpecific, return; end
if ~isstruct(dataIn) || ~isfield(dataIn,'I'), return; end
I = dataIn.I;
if ndims(I) ~= 4
    scopeInfo.sliceSpecific = false;
    scopeInfo.mode = 'all';
    return;
end
Y = size(I,1); X = size(I,2); Z = size(I,3); T = size(I,4);
z = max(1,min(Z,round(scopeInfo.zIndex)));
dataOut = dataIn;
dataOut.I = reshape(I(:,:,z,:), [Y X T]);
scopeInfo.zIndex = z;
scopeInfo.nSlices = Z;
scopeInfo.originalSize = size(I);
scopeInfo.sliceSpecific = true;
scopeInfo.mode = 'slice';
end

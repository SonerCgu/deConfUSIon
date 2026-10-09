function [TR,confirmed]=fusiBaselineAcquisitionTR(context,viewerTR,isMatrix)
% Viewer TR may contain block averaging; prefer the current raw confirmation.
TR=viewerTR;confirmed=false;if isMatrix,TR=.480;end
if isfield(context,'meta'),context=context.meta;end
if isfield(context,'rawMetadata'),context=context.rawMetadata;end
for field={'selectedTRUserSec','acquisitionTR'}
    if isfield(context,field{1})
        v=context.(field{1});
        if isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0,TR=double(v);confirmed=true;return;end
    end
end
end

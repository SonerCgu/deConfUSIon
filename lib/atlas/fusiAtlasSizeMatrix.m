function M=fusiAtlasSizeMatrix(factors,center)
% Row-vector affine scaling about the mapped scan center, in DV/AP/LR order.
if numel(factors)~=3||any(~isfinite(factors)|factors<=0)
    error('deConfUSIon:AtlasScale','Enter three finite, positive anatomy size factors.');
end
M=eye(4);M(1:3,1:3)=diag(factors);M(4,1:3)=center(:)'.*(1-factors(:)');
end

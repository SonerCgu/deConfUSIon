function scopeInfo = HUMOR_pcaica_scope_before_compute(methodName, volSize)
% V12: deprecated. No popup here anymore.
% Slice/all-slice choice is inside PCA/ICA component GUI.
if nargin < 1 || isempty(methodName), methodName = 'PCA/ICA'; end %#ok<NASGU>
if nargin < 2 || isempty(volSize), volSize = [1 1 1]; end
if numel(volSize) < 3, volSize(3) = 1; end
Z = max(1, round(volSize(3)));
scopeInfo = struct('cancelled',false,'mode','all','zIndex',1,'nSlices',Z,'sliceSpecific',false);
end

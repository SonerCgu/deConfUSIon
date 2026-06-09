function label = HUMOR_canonical_dataset_label(nameIn, dataStruct, matFile)
% V25 compatibility wrapper: preserve ordered processing chain.
if nargin < 2, dataStruct = []; end
if nargin < 3, matFile = ''; end
label = HUMOR_ordered_chain_label(nameIn, dataStruct, matFile);
end

function [T,changedRows] = gaSyncAnimalPairIDs(T,previousAnimals)
% Keep subject-derived PairIDs with corrected Animal IDs. Custom pair labels
% remain unchanged. For old lists, a PairID matching the historical source
% animal is the legacy automatic default, not a second animal identity.
changedRows=[];
if isempty(T) || size(T,2)<5,return;end
if nargin<2,previousAnimals={};end
for r=1:size(T,1)
    animal=asText(T{r,2});pair=asText(T{r,5});
    if isempty(animal),continue;end
    automatic=isempty(pair);
    if r<=numel(previousAnimals)
        automatic=automatic || strcmpi(pair,asText(previousAnimals{r}));
    elseif ~automatic && ~strcmpi(pair,animal) && size(T,2)>=6
        % Infer only an unambiguous source identity; unrelated custom PairIDs
        % (including matched pairs with different Animal IDs) take priority.
        sourceRow=T(r,:);sourceRow{2}='';
        [source,info]=gaAnimalIdentity(sourceRow);
        automatic=~info.conflict && ~isempty(source) && strcmpi(pair,source);
    end
    if automatic && ~strcmp(pair,animal)
        T{r,5}=animal;changedRows(end+1)=r; %#ok<AGROW>
    end
end
end

function text=asText(value)
text='';
if ischar(value) || (isstring(value) && isscalar(value))
    text=strtrim(char(value));
elseif isnumeric(value) && isscalar(value) && isfinite(value)
    text=num2str(value);
end
end

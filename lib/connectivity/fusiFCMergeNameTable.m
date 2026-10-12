function T=fusiFCMergeNameTable(T,registered)
% A TXT acronym list must not erase full names supplied by its registration.
if isempty(T.labels),T=registered;return;end
if ~isfield(T,'fullNames'),T.fullNames=T.names;end
for k=1:numel(T.labels)
 if ~isstruct(registered)||~isfield(registered,'labels'),continue;end
 j=find(registered.labels==T.labels(k),1);
 if isempty(j),j=find(abs(registered.labels)==abs(T.labels(k)),1);end
 if isempty(j),continue;end
 if isfield(registered,'fullNames')&&numel(registered.fullNames)>=j
  T.fullNames{k}=registered.fullNames{j};
 end
 % The registered bundle defines ID/acronym pairing and granularity.
 if isfield(registered,'names')&&numel(registered.names)>=j,T.names{k}=registered.names{j};end
end
end

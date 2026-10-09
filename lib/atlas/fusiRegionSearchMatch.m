function keep=fusiRegionSearchMatch(acronyms,names,query)
% Allen uses "area" for many cortical structures; accept familiar cortex names.
acronyms=cellstr(string(acronyms(:)));names=cellstr(string(names(:)));
query=lower(strtrim(char(query)));tokens=strsplit(query);keep=true(numel(names),1);
if isempty(query),return;end
for k=1:numel(names)
 a=acronyms{k};name=names{k};value=lower([a ' ' name]);
 a=regexprep(a,'^[LR][ _-]+','');
 cortical=any(startsWith(a,{'MOp','MOs','SSp','SSs','VIS','AUD','ACA','PL','ILA','ORB','RSP','AI','GU','VISC','TEa','PERI','ECT','ENT','PIR','COA','NLOT'}))|| ...
  any(strcmp(a,{'MO','SS'}))||~isempty(regexpi(name,'cortex|cortical|isocortex|(?:primary|secondary) (?:motor|visual|somatosensory|auditory) area','once'));
 if cortical,value=[value ' cortex cortical'];end %#ok<AGROW>
 keep(k)=all(cellfun(@(token)contains(value,token),tokens));
end
end

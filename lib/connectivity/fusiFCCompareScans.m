function result=fusiFCCompareScans(A,B,rowA,colA,rowB,colB)
% Align signed atlas identities before subtracting; never compare row positions.
[rows,ia,ib]=intersect(rowA,rowB,'stable');[cols,ja,jb]=intersect(colA,colB,'stable');
assert(~isempty(rows)&&~isempty(cols),'deConfUSIon:FCCompareRegions','These results contain no common selected atlas regions.');
result=struct('reference',A(ia,ja),'comparison',B(ib,jb),'rowLabels',rows,'columnLabels',cols, ...
    'rowIndexA',ia,'rowIndexB',ib,'columnIndexA',ja,'columnIndexB',jb);
result.difference=result.comparison-result.reference;
result.definition='Comparison scan minus reference scan, using aligned signed region labels. Descriptive difference; no significance test.';
end

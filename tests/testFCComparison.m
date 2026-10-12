function tests=testFCComparison
tests=functiontests(localfunctions);
end
function setupOnce(~),deConfUSIon_setup();end
function testSignedLabelsAlignEvenWhenOrderDiffers(test)
A=[1 .2; .2 1];B=[1 .7; .7 1];
r=fusiFCCompareScans(A,B,[-2;2],[-2;2],[2;-2],[2;-2]);
verifyEqual(test,r.rowLabels,[-2;2]);verifyEqual(test,r.columnLabels,[-2;2]);
verifyEqual(test,r.difference,[0 .5;.5 0],'AbsTol',1e-12);
end
function testRectangularHemisphereComparison(test)
r=fusiFCCompareScans([.1 .2;.3 .4],[.8 .7;.6 .5],[-1;-2],[1;2],[-2;-1],[2;1]);
verifyEqual(test,r.comparison,[.5 .6;.7 .8]);
verifyEqual(test,r.difference,.4*ones(2),'AbsTol',1e-12);
verifyError(test,@()fusiFCCompareScans(1,1,-1,1,-2,2),'deConfUSIon:FCCompareRegions');
end
function testFullNamesRetainHemisphere(test)
T=struct('names',{{'L MOp','R MOp'}},'fullNames',{{'Left primary motor area','Right primary motor area'}});
names=fusiFCFullRegionNames({'L_MOp [-1]','R MOp | Right primary motor area [1]'},T);
verifyEqual(test,names,{'Left primary motor area','Right primary motor area'});
end
function testPearsonMatchesIndependentCalculation(test)
X=[(1:12)' -(1:12)' sin((1:12)') ones(12,1)];
[R,valid]=fusiFCCorrelationMatrix(X);expected=corrcoef(X(:,1:3));
verifyEqual(test,R(1:3,1:3),expected,'AbsTol',1e-12);
verifyEqual(test,valid,[true true true false]);verifyTrue(test,all(isnan(R(4,:))));
end
function testTenScansCanBeIncludedIndependently(test)
verifyEqual(test,fusiScanSequence('maxScans'),10);
q=struct('scans',{repmat({struct('includeTrace',true)},1,10)});
q.scans{2}.includeTrace=false;q.scans{9}.includeTrace=false;
verifyEqual(test,fusiScanSequence('included',q),[true false true true true true true true false true]);
end

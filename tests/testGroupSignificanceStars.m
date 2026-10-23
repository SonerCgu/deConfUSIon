function tests=testGroupSignificanceStars
tests=functiontests(localfunctions);
end

function setupOnce(~)
addpath(fileparts(fileparts(mfilename('fullpath'))));deConfUSIon_setup();
end

function testExactThresholdsAreInclusive(testCase)
values=[0 .0009 .001 .0010001 .009 .01 .010001 .049 .05 .050001 1];
expected={'***','***','***','**','**','**','*','*','*','n.s.','n.s.'};
for k=1:numel(values),verifyEqual(testCase,gaSignificanceStars(values(k)),expected{k});end
for p=[NaN Inf -.1 1.1],verifyEqual(testCase,gaSignificanceStars(p),'p=?');end
end

function testRoundedPValueDoesNotClaimWrongStarThreshold(testCase)
verifyEqual(testCase,gaSignificanceStars(.00104),'**');
verifyEqual(testCase,gaFormatPValue(.00104),'p = 0.00104');
verifyEqual(testCase,gaFormatPValue(.0013),'p = 0.0013');
verifyEqual(testCase,gaSignificanceStars(.000999),'***');
verifyEqual(testCase,gaFormatPValue(.000999),'p < 0.001');
verifyEqual(testCase,gaFormatPValue(.001),'p = 0.001');
end

function testBoundaryRoundingNeverContradictsStars(testCase)
for boundary=[.001 .01 .05]
    for factor=[1-1e-10 1-1e-5 1+1e-10 1+1e-5]
        p=boundary*factor;label=gaFormatPValue(p);
        if p<.001
            verifyEqual(testCase,label,'p < 0.001');
        else
            displayed=sscanf(label,'p = %f');
            verifyEqual(testCase,sign(displayed-boundary),sign(p-boundary));
            verifyEqual(testCase,gaSignificanceStars(displayed),gaSignificanceStars(p));
        end
    end
end
end

function testPreviewAndExportUseSameStarsForAllDirections(testCase)
f=figure('Visible','off');guard=onCleanup(@()delete(f));ax=axes(f); %#ok<NASGU>
for label={'Two-tailed: PACAP ~= Control','One-tailed: PACAP > Control','One-tailed: PACAP < Control'}
    R=struct('metricVals',[2;5],'groupNames',{{'PACAP','Control'}}, ...
        'stats',struct('p',.001,'tailLabel',label{1}));
    gaDrawROISignificance(ax,R,struct('showPText',true),[0 0 0]);
    h=findall(ax,'Tag','GA_ROI_PLabel');
    verifyEqual(testCase,numel(h),1);
    verifyEqual(testCase,h.String,['***   p = 0.001 | ' label{1}]);
end
verifyEqual(testCase,GroupAnalysis_Common('gaPrevStars',.001),'***');
end

function testOneTailedRounded001ShowsActualNumberAndTwoStars(testCase)
S=struct('testType','Paired t-test (matched PairID / animal)','alpha',.05, ...
    'testTail','right','colorMode','Scheme','manualGroupA','PACAP','manualGroupB','Control');
delta=[-2;-1;0;1;2];n=numel(delta);p=.0013;
effect=tinv(1-p,n-1)*std(delta)/sqrt(n);a=effect+delta;b=zeros(n,1);
T=repmat({''},2*n,9);T(:,3)=[repmat({'PACAP'},n,1);repmat({'Control'},n,1)];
for k=1:2*n,T{k,2}=sprintf('Animal%d',mod(k-1,n)+1);end
stats=GroupAnalysis_Common('computeStats',[a;b],T(:,3),S,T);
verifyEqual(testCase,stats.p,p,'AbsTol',1e-12);
verifyEqual(testCase,sprintf('%.3f',stats.p),'0.001');
verifyEqual(testCase,gaSignificanceStars(stats.p),'**');
verifyEqual(testCase,gaFormatPValue(stats.p),'p = 0.0013');
f=figure('Visible','off');guard=onCleanup(@()delete(f));ax=axes(f); %#ok<NASGU>
R=struct('metricVals',[a;b],'groupNames',{{'PACAP','Control'}},'stats',stats);
gaDrawROISignificance(ax,R,struct('showPText',true),[0 0 0]);
h=findall(ax,'Tag','GA_ROI_PLabel');
verifyEqual(testCase,h.String,'**   p = 0.0013 | One-tailed: PACAP > Control');
end

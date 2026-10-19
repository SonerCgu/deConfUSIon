function limits=fusiMovieDisplayLimits(I)
% Fixed contrast over time, separately for each acquired plane. Sample at
% most twenty time points instead of sorting a complete multi-GB movie.
T=size(I,ndims(I));times=unique(round(linspace(1,T,min(T,20))));
Z=1;if ndims(I)==4,Z=size(I,3);end
limits=zeros(Z,2);
for z=1:Z
 if ndims(I)==4,plane=I(:,:,z,times);else,plane=I(:,:,times);end
 limits(z,:)=fusiFiniteDisplayLimits(plane);
end
end

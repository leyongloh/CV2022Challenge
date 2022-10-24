%Author: @Leyong @Maximilian

% This functions resizes the planes according to the 3D Model
% \param planecell:                                                         planes in a cellarray
% \param [d_left, d_top, d_right, d_bottom]:                                3D depth of the planes
% \return [rearplane, leftplane, ceilingplane, rightplane, bottomplane]:    resized planes
function resized_planes = create3Dplanes(image ,planecell, depth)
    
    %definitions
    rearP =     planecell{1};
    leftP =     planecell{2};
    ceilingP =  planecell{3};
    rightP =    planecell{4};
    bottomP =   planecell{5};
    
    %sizes of the image boundarys
    maxX = size(image, 2);
    maxY = size(image, 1);
    
    %resize rare plane
    rearplane = imresize(rearP,[maxY maxX]);
    
    %resize left plane
    leftplane = imresize(leftP, [maxY depth(1)]);
    
    %resize ceiling plane
    ceilingplane = imresize(ceilingP, [depth(2) maxX]);
    
    %resize right plane
    rightplane = imresize(rightP, [maxY depth(3)]);
    
    %resize bottom plane
    bottomplane = imresize(bottomP, [depth(4) maxX]);
    
    %put them in a cell for further processing
    resized_planes = {rearplane, leftplane, ceilingplane, rightplane, bottomplane};
    
end

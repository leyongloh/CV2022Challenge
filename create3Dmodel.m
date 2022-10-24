%Author: @Maximilian Studt
%\param vertecis:   vertecis of the 2D image + Vanishing point defined by the user 
%\param f:          is the focal distance
%\param do_plot:    makes a plot of the 3D Box set to True
%\return:           The depths of the 3D Box, 3D coordinates

function [d_left, d_top, d_right, d_bottom, coordinates3D] = create3Dmodel(image, f, vertecis)
    %%
    %Getting Image Hight and Width
    im_h = size(image,1);
    im_w = size(image, 2);
    
    %Calculate helpful lengths of the sideview
    VC_side = abs(vertecis(2,9)-vertecis(2,3)); %distance between V and C on the Projection plane in the side view
    BV_side = abs(vertecis(2,2)-vertecis(2,9)); %distance between B and V on the Projection plane in the side view
    
    V_C_side = abs(im_h - vertecis(2,9)); %distance between V and C on the rare plane in the side view
    B_V_side = abs(vertecis(2,9)); %distance between B and V on the rare plane in the side view
    
    %Calculate helpful lengths of the top view
    AV_top = abs(vertecis(1,9) - vertecis(1,1)); %distance between A and V on the Projection plane in the top view
    CV_top = abs(vertecis(1,9) - vertecis(1,3)); %distance between C and V on the Projection plane in the top view
    
    V_C_top = abs(vertecis(1,9) - im_w); %distance between V and C on the rare plane in the top view
    A_V_top = abs(vertecis(1,9)); %distance between V and A on the rare plane in the top view
    
    %Calculate the depth of the top and bottom plane
    d_top = ceil((f/BV_side)*B_V_side - f);
    d_bottom = ceil((f/VC_side)*V_C_side - f);
    
    %Calculate the depth of the left and right plane
    d_left = ceil((f/AV_top)*A_V_top - f);
    d_right = ceil((f/CV_top)*V_C_top - f);
    
    %%
    %Rare plane 3D coordinates Vertices
    TopLeftBack = [0 0 0];
    TopRightBack = [im_w 0 0];
    BottomRightBack = [im_w im_h 0];
    BottomLeftBack = [0 im_h 0];
    
    %Ceiling plane 3D coordinates Vertices
    TopLeftFront = [0 0 d_top];
    TopRightFront = [im_w 0 d_top];
    
    %Bottom plane 3D coordinates Vertices
    BottomLeftFront = [0 im_h d_bottom];
    BottomRightFront = [im_w im_h d_bottom];
    
    %Left plane 3D coordinates Vertices
    TopLeftFront_leftplane = [0 0 d_left];
    BottomLeftFront_leftplane = [0 im_h d_left];
    
    %Right plane 3D coordinates Vertices
    TopRightFront_rightplane = [im_w 0 d_right];
    BottomRightFront_rightplane = [im_w im_h d_right];
    
    coordinates3D = [TopLeftBack; 
                    TopRightBack;
                    BottomRightBack; 
                    BottomLeftBack;
                    TopLeftFront;
                    TopRightFront; 
                    BottomRightFront;
                    BottomLeftFront;
                    TopLeftFront_leftplane; 
                    TopRightFront_rightplane;
                    BottomRightFront_rightplane;
                    BottomLeftFront_leftplane];

end

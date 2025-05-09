#include "stdint.h"
#include "stdio.h"
#include "stdlib.h"
#include "moc_nn.h"


const mocnn_tensor my_in_tensor = {
    .nN     = 10    ,
    .nC     = 4     ,
    .nH     = 8     ,
    .nW     = 8     ,
    .nScale = 1     ,
    .nZP    = 0     
};

const mocnn_tensor my_out_tensor = {
    .nN     = 20    ,
    .nC     = 4     ,
    .nH     = 8     ,
    .nW     = 8     ,
    .nScale = 1     ,
    .nZP    = 0     
};

const mocnn_tensor my_kernel_tensor = {
    .nN     = 20    ,
    .nC     = 4     ,
    .nH     = 8     ,
    .nW     = 8     ,
    .nScale = 1     ,
    .nZP    = 0     
};

const mocnn_linear_param my_linear_param = {
    .nInFeatures    = 10    ,
    .nOutFeatures   = 20    ,
    .uchActValue    = 0
};
void run_nn_linear(){
    printf("Entering NN Linear\n");
    const mocnn_tensor *in_tensor = &my_in_tensor;
    const mocnn_tensor *out_tensor = &my_out_tensor;
    const mocnn_tensor *kernel_tensor = &my_kernel_tensor;
    const mocnn_linear_param *linear_param = &my_linear_param;

    MOCNN_Linear(in_tensor, out_tensor, kernel_tensor, linear_param);
}

int main()
{
    run_nn_linear();
    return 0;
}
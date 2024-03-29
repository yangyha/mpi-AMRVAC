!##############################################################################
! module fff
! PURPOSE:
! Program to extrapolate linear force-free fields in 3D Cartesian coordinates,
! based on exact Green function method (Chiu & Hilton 1977 ApJ 212,873).
! Usage:
!1 In amrvacusr.t, put a line:
!  INCLUDE:amrvacmodules/fff.t
!2 In the subroutine initglobaldata_usr of amrvacusr.t:
!  To extrapolate a linear force free field from an analytical magnetogram, 
!  add lines like:
!  
!  logical, save :: firstusrglobaldata=.true.
! 
!  if(firstusrglobaldata) then
!
!    call init_bc_fff(600,360)
!    firstusrglobaldata=.false.
!  endif
!
!  600 x 360 is the resolution of the magnetogram. Users can use subroutine
!  init_bc_fff as an example and make a similar subroutine creating any
!  analytical magnetograms.
!  To extrapolate a linear force free field from a observed magnetogram 
!  prepared in a data file, e.g., 'hmiM720sxxxx.dat' replace 
!  "call init_bc_fff(xx,xx)" used above by
!  call init_bc_fff_data('hmiM720sxxxx.dat',Lunit,Bunit)
!  Lunit and Bunit are dimensionless unit for length and magnetic field.
!  'hmiM720sxxxx.dat' must be a binary file containing nx1,nx2,xc1,xc2,dxm1,
!  dxm2, Bz0(nx1,nx2). Integers nx1 and nx2 give the resolution of the 
!  uniform-grid magentogram. Others are double-precision floats. xc1 and xc2
!  are coordinates of the central point of the magnetogram. dxm1 and dxm2 
!  are the cell sizes for each direction, Bz0 is the vertical conponent 
!  of magetic field on the solar surface from observations.
!3 In the subroutine initonegrid_usr of amrvacusr.t,
!  add lines like:
!
!  double precision :: Bf(ixG^S,1:ndir), alpha, zshift
!
!  alpha=0.d0     ! potential field
!  !alpha=0.08d0  ! non-potential linear force-free field
!  zshift=0.05d0  ! lift your box zshift heigher to the bottom magnetogram
!  call calc_lin_fff(ixG^L,ix^L,Bf,x,alpha,zshift) 
!
! Notice that the resolution of input magnetogram must be better than the best
!  resolution of your AMR grid to have a good behavior in the bottom layer
! when zshift=0.
!============================================================================= 
module fff_global
implicit none

integer, save :: nx1,nx2
double precision, save :: Bzmax,darea
double precision, allocatable, save :: Bz0(:,:)
double precision, allocatable, save :: xa1(:),xa2(:)

end module fff_global
!============================================================================= 
subroutine init_b_fff_data(magnetogramname,qLunit,qBunit)
use fff_global

include 'amrvacdef.f'
double precision, intent(in) :: qLunit,qBunit
double precision :: xc1,xc2,dxm1,dxm2
integer, dimension(MPI_STATUS_SIZE) :: statuss
integer :: file_handle,i
character(len=*), intent(in) :: magnetogramname
logical :: aexist
!-----------------------------------------------------------------------------
! nx1,nx2 are numbers of cells for each direction
! xc1,xc2 are coordinates of the central point of the magnetogram
! dxm1,dxm2 are cell sizes for each direction
! Bz0 is the 2D Bz magnetogram
inquire(file=magnetogramname,exist=aexist)
if(.not. aexist) then
  if(mype==0) write(*,'(2a)') "can not find file:",magnetogramname
  call mpistop("no input magnetogram----init_b_fff_data")
end if
call MPI_FILE_OPEN(icomm,magnetogramname,MPI_MODE_RDONLY,MPI_INFO_NULL,&
                   file_handle,ierrmpi)
call MPI_FILE_READ_ALL(file_handle,nx1,1,MPI_INTEGER,statuss,ierrmpi)
call MPI_FILE_READ_ALL(file_handle,nx2,1,MPI_INTEGER,statuss,ierrmpi)
allocate(Bz0(nx1,nx2))
call MPI_FILE_READ_ALL(file_handle,xc1,1,MPI_DOUBLE_PRECISION,statuss,ierrmpi)
call MPI_FILE_READ_ALL(file_handle,xc2,1,MPI_DOUBLE_PRECISION,statuss,ierrmpi)
call MPI_FILE_READ_ALL(file_handle,dxm1,1,MPI_DOUBLE_PRECISION,statuss,ierrmpi)
call MPI_FILE_READ_ALL(file_handle,dxm2,1,MPI_DOUBLE_PRECISION,statuss,ierrmpi)
call MPI_FILE_READ_ALL(file_handle,Bz0,nx1*nx2,MPI_DOUBLE_PRECISION,&
                       statuss,ierrmpi)
call MPI_FILE_CLOSE(file_handle,ierrmpi)
allocate(xa1(nx1))
allocate(xa2(nx2))
xa1(nx1/2)=xc1
xa2(nx2/2)=xc2
do i=nx1/2+1,nx1
  xa1(i)=xa1(nx1/2)+dble(i-nx1/2)*dxm1
enddo
do i=nx1/2-1,1,-1
  xa1(i)=xa1(nx1/2)+dble(i-nx1/2)*dxm1
enddo
do i=nx2/2+1,nx2
  xa2(i)=xa2(nx2/2)+dble(i-nx2/2)*dxm2
enddo
do i=nx2/2-1,1,-1
  xa2(i)=xa2(nx2/2)+dble(i-nx2/2)*dxm2
enddo
! declare and define global variables Lunit and Bunit to be your length unit in
! cm and magnetic strength unit in Gauss first
dxm1=dxm1/qLunit
dxm2=dxm2/qLunit
xa1=xa1/qLunit
xa2=xa2/qLunit
darea=dxm1*dxm2
Bz0=Bz0/qBunit
Bzmax=maxval(dabs(Bz0(:,:)))

! normalize b
Bz0=Bz0/Bzmax
if(mype==0) then
  print*,'magnetogram xrange:',minval(xa1),maxval(xa1)
  print*,'magnetogram yrange:',minval(xa2),maxval(xa2)
end if

if(mype==0) then
  print*,'extrapolating 3D force-free field from an observed Bz '
  print*,'magnetogram of',nx1,'by',nx2,'pixels. Bzmax=',Bzmax
endif

end subroutine init_b_fff_data
!============================================================================= 
subroutine init_b_fff(qnx1,qnx2)
use fff_global

include 'amrvacdef.f'

double precision :: dxm1,dxm2,delx1,delx2,xo1,xo2,yo1,yo2,coB,B0
integer :: i1,i2,qnx1,qnx2
!-----------------------------------------------------------------------------
nx1=qnx1
nx2=qnx2
allocate(Bz0(nx1,nx2))
allocate(xa1(nx1))
allocate(xa2(nx2))
dxm1=(xprobmax1-xprobmin1)/dble(nx1)
dxm2=(xprobmax2-xprobmin2)/dble(nx2)
darea=dxm1*dxm2
do i1=1,nx1
  xa1(i1)=xprobmin1+(dble(i1)-0.5d0)*dxm1
enddo
do i2=1,nx2
  xa2(i2)=xprobmin2+(dble(i2)-0.5d0)*dxm2
enddo

xo1=(xprobmax1+xprobmin1)/2.d0
xo2=xo1
yo1=(xprobmax2+xprobmin2)/2.d0-(xprobmax2-xprobmin2)*0.15d0
yo2=(xprobmax2+xprobmin2)/2.d0+(xprobmax2-xprobmin2)*0.15d0
delx1=(xprobmax1-xprobmin1)*0.3d0
delx2=(xprobmax2-xprobmin2)*0.12d0

! Bz are composed by two elliptic 2D Gaussian functions to mimic a bipole 
B0=10.d0
do i2=1,nx2
  do i1=1,nx1
    Bz0(i1,i2)=B0*(dexp(-((xa1(i1)-xo1)**2/delx1**2+&
                    (xa2(i2)-yo1)**2/delx2**2)/2.d0)-&
                    dexp(-((xa1(i1)-xo2)**2/delx1**2+&
                    (xa2(i2)-yo2)**2/delx2**2)/2.d0))
  enddo
enddo

Bzmax=maxval(dabs(Bz0(:,:)))
! normalize b
Bz0=Bz0/Bzmax
if(mype==0) then
  print*,'extrapolating 3D force-free field from an analytical Bz '
  print*,'magnetogram of',nx1,'by',nx2,'pixels. Bzmax=',Bzmax
endif

end subroutine init_b_fff
!============================================================================= 
subroutine calc_lin_fff(ixI^L,ixO^L,Bf,x,alpha,zshift)
! PURPOSE: 
! Calculation to determine linear FFF from the field on 
! the lower boundary (Chiu and Hilton 1977 ApJ 212,873). 
! NOTE: Only works for Cartesian coordinates 
! INPUT: Bf,x
! OUTPUT: updated b in w 
use fff_global

include 'amrvacdef.f'

integer, intent(in) :: ixI^L, ixO^L
double precision, intent(in) :: x(ixI^S,1:ndim),alpha,zshift
double precision, intent(inout) :: Bf(ixI^S,1:ndir)

double precision :: cos_az(ixO^S),sin_az(ixO^S),zk(ixO^S)
double precision :: r, r2, r3, bigr, cos_ar, sin_ar, xsum, ysum, zsum
double precision :: g, dgdz, gx, gy, gz, twopiinv
integer :: ix1,ix2,ix3,ixp1,ixp2
!-----------------------------------------------------------------------------

Bf=0.d0
twopiinv = 0.5d0/dpi
! get cos and sin arrays
zk(ixO^S)=x(ixO^S,3)-xprobmin3+zshift
cos_az(ixO^S)=dcos(alpha*zk(ixO^S))
sin_az(ixO^S)=dsin(alpha*zk(ixO^S))
! 5 loops, for each grid integrate over x and y of Bz0
do ix3=ixOmin3,ixOmax3
  do ix2=ixOmin2,ixOmax2
    do ix1=ixOmin1,ixOmax1
      xsum = 0.d0
      ysum = 0.d0
      zsum = 0.d0
      do ixp2=1,nx2
        do ixp1=1,nx1
          bigr=dsqrt((x(ix1,ix2,ix3,1)-xa1(ixp1))**2+&
                    (x(ix1,ix2,ix3,2)-xa2(ixp2))**2)
          if(bigr>smalldouble) then
            r2=bigr**2+zk(ix1,ix2,ix3)**2
            r=dsqrt(r2)
            r3=r**3
            cos_ar=dcos(alpha*r)
            sin_ar=dsin(alpha*r)
            bigr=1.d0/bigr
            g=(zk(ix1,ix2,ix3)*cos_ar/r-cos_az(ix1,ix2,ix3))*bigr
            dgdz=(cos_ar*(1.d0/r-zk(ix1,ix2,ix3)**2/r3)&
                 -alpha*zk(ix1,ix2,ix3)**2*sin_ar/r2&
                 +alpha*sin_az(ix1,ix2,ix3))*bigr
            gx=Bz0(ixp1,ixp2)*((x(ix1,ix2,ix3,1)-xa1(ixp1))*dgdz&
               +alpha*g*(x(ix1,ix2,ix3,2)-xa2(ixp2)))*bigr
            gy=Bz0(ixp1,ixp2)*((x(ix1,ix2,ix3,2)-xa2(ixp2))*dgdz&
               -alpha*g*(x(ix1,ix2,ix3,1)-xa1(ixp1)))*bigr
            gz=Bz0(ixp1,ixp2)*(zk(ix1,ix2,ix3)*cos_ar/r3+alpha*&
               zk(ix1,ix2,ix3)*sin_ar/r2)
            xsum=xsum+gx*darea
            ysum=ysum+gy*darea
            zsum=zsum+gz*darea
          end if
        end do
      end do
      Bf(ix1,ix2,ix3,1)=xsum*twopiinv
      Bf(ix1,ix2,ix3,2)=ysum*twopiinv
      Bf(ix1,ix2,ix3,3)=zsum*twopiinv
    end do
  end do
end do
Bf=Bf*Bzmax

end subroutine calc_lin_fff
!============================================================================= 

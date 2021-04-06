#!/usr/env python3

import numpy as np
import matplotlib.pyplot as plt

fname=input('File: ')
#d1,d2=np.loadtxt('/home/arnaldi/dada2',unpack=True)                                                                  
d1,d2=np.loadtxt(fname,unpack=True)                                                                  
l1=np.flipud(d1[2**13:])                                                                           
u1=np.flipud(d1[:2**13])
r1=np.flipud(np.hstack((u1,l1)))
l2=np.flipud(d2[2**13:])                                                                           
u2=np.flipud(d2[:2**13])
r2=np.flipud(np.hstack((u2,l2)))
t=np.arange(-1,1,1/2**13)
n=np.arange(d1.size)

fig,ax=plt.subplots(3,2,figsize=(10,10))
ax[0][0].set_title('CH1')
ax[0][0].semilogy(d1-2**14)
ax[0][0].set_xlim(-2**13,2**13)
ax[0][0].grid()
ax[0][0].set_xlabel('Cuenta ADC')

ax[1][0].semilogy(t,r1)
ax[1][0].set_xlim(min(t),max(t))
ax[1][0].grid()
ax[1][0].set_xlabel('Voltaje (V)')

#ax[2][0].plot(n,r1)
ax[2][0].semilogy(n,r1)
ax[2][0].set_xlim(min(n),max(n))
ax[2][0].grid()
ax[2][0].set_xlabel('Cuenta ADC')

ax[0][1].set_title('CH2')
ax[0][1].semilogy(d2-2**14)
ax[0][1].set_xlim(-2**13,2**13)
ax[0][1].grid()
ax[0][1].set_xlabel('Cuenta ADC')

ax[1][1].semilogy(t,r2)
ax[1][1].set_xlim(min(t),max(t))
ax[1][1].grid()
ax[1][1].set_xlabel('Voltaje (V)')

#ax[2][1].plot(n,r2)
ax[2][1].semilogy(n,r1)
ax[2][1].set_xlim(min(n),max(n))
ax[2][1].grid()
ax[2][1].set_xlabel('Cuenta ADC')

plt.tight_layout()
plt.show()

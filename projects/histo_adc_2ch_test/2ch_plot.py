#!/usr/env python3

import numpy as np
import matplotlib.pyplot as plt

d1,d2=np.loadtxt('/home/arnaldi/dada',unpack=True)                                                                  
l1=np.flipud(d1[8192:])                                                                           
u1=np.flipud(d1[:8192])
r1=np.hstack((u1,l1))
l2=np.flipud(d2[8192:])                                                                           
u2=np.flipud(d2[:8192])
r2=np.hstack((u2,l2))
t=np.arange(-1,1,1/2**13)

fig,ax=plt.subplots(2,2,figsize=(10,10))
#ax.semilogy(t,r)
ax[0][0].set_title('CH1')
ax[0][0].semilogy(d1)
ax[0][0].set_xlim(0,2**14)
ax[0][0].grid()
ax[0][0].set_xlabel('Cuenta ADC')

ax[1][0].semilogy(t,r1)
ax[1][0].set_xlim(min(t),max(t))
ax[1][0].grid()
ax[1][0].set_xlabel('Voltaje (V)')

ax[0][1].set_title('CH2')
ax[0][1].semilogy(d2)
ax[0][1].set_xlim(0,2**14)
ax[0][1].grid()
ax[0][1].set_xlabel('Cuenta ADC')

ax[1][1].semilogy(t,r2)
ax[1][1].set_xlim(min(t),max(t))
ax[1][1].grid()
ax[1][1].set_xlabel('Voltaje (V)')
plt.tight_layout()

plt.show()

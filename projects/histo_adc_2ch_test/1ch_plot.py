#!/usr/env python3

import numpy as np
import matplotlib.pyplot as plt

d=np.loadtxt('/home/arnaldi/dada')                                                                  
l=np.flipud(d[8192:])                                                                           
u=np.flipud(d[:8192])
r=np.hstack((u,l))
t=np.arange(-1,1,1/2**13)

fig,ax=plt.subplots(2,1,figsize=(10,10))
#ax.semilogy(t,r)
ax[0].semilogy(d)
ax[0].set_xlim(0,2**14)
ax[0].grid()

ax[1].semilogy(t,r)
ax[1].set_xlim(min(t),max(t))
ax[1].grid()
plt.tight_layout()


plt.show()

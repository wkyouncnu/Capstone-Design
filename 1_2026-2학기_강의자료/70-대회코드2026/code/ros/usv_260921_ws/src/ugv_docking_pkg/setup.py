import os
from glob import glob
from setuptools import find_packages, setup

package_name = 'ugv_docking_pkg'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*launch.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='holybro',
    maintainer_email='holybro@todo.todo',
    description='UGV docking mission package using LiDAR bay detection',
    license='TODO: License declaration',
    extras_require={
        'test': ['pytest'],
    },
    entry_points={
        'console_scripts': [
            'docking_3bay_pc2_ransac_flight_ver2 = ugv_docking_pkg.docking_3bay_pc2_ransac_flight_ver2:main', # ver2: 안쪽벽 실측/추론
        ],
    },
)
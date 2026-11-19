import os
from glob import glob

from setuptools import find_packages, setup

package_name = 'buoy_avoidance_pkg'

setup(
    name=package_name,
    version='0.0.1',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob('launch/*.launch.py')),
        (os.path.join('share', package_name, 'config'), glob('config/*')),
        (os.path.join('share', package_name, 'tools'), glob('tools/*.py')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='ansl1',
    maintainer_email='cnuansl2026@gmail.com',
    description=(
        'KABOAT 2026 spherical red/green buoy channel navigation: LiDAR Euclidean '
        'clustering for position, fisheye-camera HSV patch for color, gate-midpoint '
        'planner publishing /vfh/command + /vfh/oa_flag gated by operation_mode.'
    ),
    license='TODO',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'buoy_avoidance_node = buoy_avoidance_pkg.buoy_avoidance_node:main',
        ],
    },
)

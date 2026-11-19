import os
from glob import glob
from setuptools import find_packages, setup

package_name = 'auto_usv_pkg'

setup(
    name=package_name,
    version='0.0.0',
    packages=find_packages(exclude=['test']),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        (os.path.join('share', package_name, 'launch'), glob(os.path.join('launch', '*.launch.py'))),
        (os.path.join('share', package_name, 'config'), glob(os.path.join('config', '*.yaml'))),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='ansl',
    maintainer_email='ansl@todo.todo',
    description='TODO: Package description',
    license='TODO: License declaration',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'pos_trans = auto_usv_pkg.coordinate_transformer_node:main',
            'collision_avoidance_node_livox = auto_usv_pkg.collision_avoidance_node_livox:main',
            'px4_cmd_pub = auto_usv_pkg.px4_mission_msg_pub_node:main',
        ],
    },
)

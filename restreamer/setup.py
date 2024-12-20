from setuptools import setup, find_packages

setup(
	name = "wubloader-restreamer",
	version = "0.0.0",
	packages = find_packages(),
	install_requires = [
		"argh==0.28.1",
		"python-dateutil",
		"flask",
		"gevent",
		"monotonic",
		"Pillow", # for thumbnail templates
		"prometheus-client",
		"psycogreen",
		"psycopg2",
		"wubloader-common",
	],
)

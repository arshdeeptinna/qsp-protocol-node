####################################################################################################
#                                                                                                  #
# (c) 2018 Quantstamp, Inc. All rights reserved.  This content shall not be used, copied,          #
# modified, redistributed, or otherwise disseminated except to the extent expressly authorized by  #
# Quantstamp for credentialed users. This content and its use are governed by the Quantstamp       #
# Demonstration License Terms at <https://s3.amazonaws.com/qsp-protocol-license/LICENSE.txt>.      #
#                                                                                                  #
####################################################################################################

"""
Provides functions related to testing resources.
"""
import os


def resource_uri(path, is_main=False):
    """
    Returns the filesystem URI of a given resource.
    """
    if is_main:
        return "file://{0}/../../qsp_protocol_node/{1}".format(os.path.dirname(__file__), path)
    else:
        return "file://{0}/../resources/{1}".format(os.path.dirname(__file__), path)


def project_root():
    """
    Returns the root folder of the audit node project.
    """
    return os.path.abspath("{0}/../../".format(os.path.dirname(__file__)))

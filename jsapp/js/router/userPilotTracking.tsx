import React from 'react';
import {useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import userpilot from 'js/userpilot';

export const UserPilotRouteTracking = ()=> {
  const location = useLocation();
  useEffect(() => {
    userpilot.reload(window.location.href);
  }, [location]);
  return <></>;
}

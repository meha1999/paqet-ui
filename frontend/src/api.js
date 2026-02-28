import axios from "axios";

const api = axios.create({
  baseURL: "/panel/api",
  withCredentials: true,
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error?.response?.status;
    const url = String(error?.config?.url || "");
    const isLoginCall = url.includes("/auth/login");
    const onLoginPage = window.location.pathname === "/panel/login";

    if (status === 401 && !isLoginCall && !onLoginPage) {
      window.location.href = "/panel/login";
    }

    return Promise.reject(error);
  },
);

export function extractErrorMessage(error, fallback) {
  if (error?.response?.data?.detail) {
    return String(error.response.data.detail);
  }
  return fallback;
}

export default api;

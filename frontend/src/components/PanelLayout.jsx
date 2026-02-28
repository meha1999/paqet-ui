import {
  Button,
  Navbar,
  NavbarBrand,
  NavbarContent,
  NavbarItem,
} from "@heroui/react";
import { NavLink, Outlet, useLocation } from "react-router-dom";

function LinkItem({ to, label }) {
  const location = useLocation();
  const isActive = location.pathname.startsWith(to);

  return (
    <NavLink
      to={to}
      className={[
        "rounded-md px-3 py-2 text-sm font-medium transition-colors",
        isActive
          ? "bg-primary text-primary-foreground"
          : "text-default-600 hover:bg-default-100 hover:text-default-900",
      ].join(" ")}
    >
      {label}
    </NavLink>
  );
}

export default function PanelLayout() {
  return (
    <div className="min-h-screen bg-default-100">
      <Navbar isBordered maxWidth="full" className="bg-white">
        <NavbarBrand>
          <p className="font-semibold">Paqet UI</p>
        </NavbarBrand>

        <NavbarContent justify="center" className="gap-1 sm:gap-2">
          <NavbarItem>
            <LinkItem to="/dashboard" label="Dashboard" />
          </NavbarItem>
          <NavbarItem>
            <LinkItem to="/configurations" label="Configurations" />
          </NavbarItem>
          <NavbarItem>
            <LinkItem to="/connections" label="Connections" />
          </NavbarItem>
          <NavbarItem>
            <LinkItem to="/settings" label="Settings" />
          </NavbarItem>
        </NavbarContent>

        <NavbarContent justify="end">
          <NavbarItem>
            <Button
              color="danger"
              variant="flat"
              size="sm"
              onPress={() => {
                window.location.href = "/panel/logout";
              }}
            >
              Logout
            </Button>
          </NavbarItem>
        </NavbarContent>
      </Navbar>

      <main className="mx-auto w-full max-w-7xl p-4 sm:p-6">
        <Outlet />
      </main>
    </div>
  );
}

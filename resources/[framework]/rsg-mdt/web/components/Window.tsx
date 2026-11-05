import React, { useState, useRef, useCallback, useEffect } from 'react';
import { fetchNui } from '../hooks/useNui';

interface WindowProps {
  title: string;
  subtitle?: string;
  initialWidth?: number;
  initialHeight?: number;
  minWidth?: number;
  minHeight?: number;
  children: React.ReactNode;
  onClose: () => void;
}

interface WindowState {
  x: number;
  y: number;
  width: number;
  height: number;
}

export function Window({
  title,
  subtitle,
  initialWidth = 1100,
  initialHeight = 700,
  minWidth = 800,
  minHeight = 500,
  children,
  onClose,
}: WindowProps) {
  const [state, setState] = useState<WindowState>(() => ({
    x: (window.innerWidth - initialWidth) / 2,
    y: (window.innerHeight - initialHeight) / 2,
    width: initialWidth,
    height: initialHeight,
  }));

  const [isDragging, setIsDragging] = useState(false);
  const [isResizing, setIsResizing] = useState(false);
  const dragOffset = useRef({ x: 0, y: 0 });
  const resizeStart = useRef({ x: 0, y: 0, width: 0, height: 0 });

  // Drag handlers
  const handleDragStart = useCallback((e: React.MouseEvent) => {
    if (e.button !== 0) return;
    setIsDragging(true);
    dragOffset.current = {
      x: e.clientX - state.x,
      y: e.clientY - state.y,
    };
  }, [state.x, state.y]);

  const handleDragMove = useCallback((e: MouseEvent) => {
    if (!isDragging) return;
    const newX = Math.max(0, Math.min(window.innerWidth - 100, e.clientX - dragOffset.current.x));
    const newY = Math.max(0, Math.min(window.innerHeight - 50, e.clientY - dragOffset.current.y));
    setState(prev => ({ ...prev, x: newX, y: newY }));
  }, [isDragging]);

  const handleDragEnd = useCallback(() => {
    if (isDragging) {
      setIsDragging(false);
    }
  }, [isDragging]);

  // Resize handlers
  const handleResizeStart = useCallback((e: React.MouseEvent) => {
    if (e.button !== 0) return;
    e.preventDefault();
    e.stopPropagation();
    setIsResizing(true);
    resizeStart.current = {
      x: e.clientX,
      y: e.clientY,
      width: state.width,
      height: state.height,
    };
  }, [state.width, state.height]);

  const handleResizeMove = useCallback((e: MouseEvent) => {
    if (!isResizing) return;
    const deltaX = e.clientX - resizeStart.current.x;
    const deltaY = e.clientY - resizeStart.current.y;
    const newWidth = Math.max(minWidth, resizeStart.current.width + deltaX);
    const newHeight = Math.max(minHeight, resizeStart.current.height + deltaY);
    setState(prev => ({ ...prev, width: newWidth, height: newHeight }));
  }, [isResizing, minWidth, minHeight]);

  const handleResizeEnd = useCallback(() => {
    if (isResizing) {
      setIsResizing(false);
      fetchNui('windowResize', { width: state.width, height: state.height });
    }
  }, [isResizing, state.width, state.height]);

  // Global mouse events
  useEffect(() => {
    if (isDragging) {
      window.addEventListener('mousemove', handleDragMove);
      window.addEventListener('mouseup', handleDragEnd);
      return () => {
        window.removeEventListener('mousemove', handleDragMove);
        window.removeEventListener('mouseup', handleDragEnd);
      };
    }
  }, [isDragging, handleDragMove, handleDragEnd]);

  useEffect(() => {
    if (isResizing) {
      window.addEventListener('mousemove', handleResizeMove);
      window.addEventListener('mouseup', handleResizeEnd);
      return () => {
        window.removeEventListener('mousemove', handleResizeMove);
        window.removeEventListener('mouseup', handleResizeEnd);
      };
    }
  }, [isResizing, handleResizeMove, handleResizeEnd]);

  return (
    <div
      className="fixed flex flex-col overflow-hidden rounded-lg shadow-2xl"
      style={{
        left: state.x,
        top: state.y,
        width: state.width,
        height: state.height,
        background: 'linear-gradient(180deg, #111113 0%, #0a0a0b 100%)',
        border: '1px solid rgba(255, 255, 255, 0.08)',
        boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(255, 255, 255, 0.05)',
      }}
    >
      {/* Titlebar */}
      <div
        className="flex items-center justify-between px-4 py-3 select-none"
        style={{
          background: 'linear-gradient(180deg, #1a1a1c 0%, #141416 100%)',
          borderBottom: '1px solid rgba(255, 255, 255, 0.06)',
          cursor: isDragging ? 'grabbing' : 'grab',
        }}
        onMouseDown={handleDragStart}
      >
        <div className="flex items-center gap-3">
          <div className="flex gap-1.5">
            <button
              onClick={(e) => { e.stopPropagation(); onClose(); }}
              className="w-3 h-3 rounded-full bg-red-500/80 hover:bg-red-500 transition-colors"
              title="Close"
            />
            <div className="w-3 h-3 rounded-full bg-amber-500/30" />
            <div className="w-3 h-3 rounded-full bg-amber-500/30" />
          </div>
          <div>
            <h1 className="text-white text-sm font-semibold tracking-wide" style={{ fontFamily: 'var(--font-display)' }}>
              {title}
            </h1>
            {subtitle && (
              <p className="text-zinc-600 text-xs">{subtitle}</p>
            )}
          </div>
        </div>
        <button
          onClick={onClose}
          className="text-zinc-600 hover:text-zinc-300 text-sm transition-colors px-2 py-1 rounded hover:bg-white/5"
        >
          ✕
        </button>
      </div>

      {/* Content */}
      <div className="flex-1 flex overflow-hidden">
        {children}
      </div>

      {/* Resize Handle */}
      <div
        className="absolute bottom-0 right-0 w-4 h-4 cursor-se-resize"
        onMouseDown={handleResizeStart}
        style={{
          background: `linear-gradient(135deg, transparent 50%, rgba(255, 255, 255, 0.1) 50%)`,
        }}
      />
    </div>
  );
}

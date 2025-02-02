const LoadingSpinner = () => {
  return (
    <div className="flex justify-center items-center h-[600px] card">
      <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-orange-500"></div>
    </div>
  );
};

export default LoadingSpinner;
